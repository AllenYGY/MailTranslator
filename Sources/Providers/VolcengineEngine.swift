import Foundation

/// 火山引擎机器翻译：TextList 批量接口，一次请求翻译整批分段。
/// 文档：https://www.volcengine.com/docs/4640/65067
struct VolcengineEngine: TranslationEngine {
    let config: VolcengineProviderConfig

    var kind: ProviderKind { .volcengine }
    var batchCharacterLimit: Int { 3000 }
    var maxConcurrentBatches: Int { 4 } // 免费额度限流 10 QPS，留余量

    private let host = "translate.volcengineapi.com"
    private let uri = "/"
    private let queryString = "Action=TranslateText&Version=2020-06-01"
    private let region = "cn-north-1"
    private let service = "translate"

    private struct ResponseBody: Decodable {
        struct Translation: Decodable {
            let translation: String?
            enum CodingKeys: String, CodingKey {
                case translation = "Translation"
            }
        }
        struct Metadata: Decodable {
            struct ResponseError: Decodable {
                let message: String?
                enum CodingKeys: String, CodingKey {
                    case message = "Message"
                }
            }
            let error: ResponseError?
            enum CodingKeys: String, CodingKey {
                case error = "Error"
            }
        }
        let translationList: [Translation]?
        let responseMetadata: Metadata?
        enum CodingKeys: String, CodingKey {
            case translationList = "TranslationList"
            case responseMetadata = "ResponseMetaData"
        }
    }

    func translate(
        batch: [TranslationInput],
        target: TargetLanguage,
        onSegment: @Sendable (Int, String) -> Void
    ) async throws -> [Int: String] {
        try Task.checkCancellation()
        guard config.isConfigured else {
            throw EngineError.notConfigured("请打开 MailTranslator 应用配置火山翻译 AccessKey")
        }

        // 传统机器翻译不保证保留 HTML 标签，送纯文本、插入时转义。
        let bodyJSON: [String: Any] = [
            "TargetLanguage": target.volcCode,
            "TextList": batch.map(\.plainText),
        ]
        let body = try JSONSerialization.data(withJSONObject: bodyJSON)

        let headers = VolcengineSigner.sign(
            accessKeyID: config.accessKeyID,
            secretAccessKey: config.secretAccessKey,
            host: host,
            uri: uri,
            queryString: queryString,
            region: region,
            service: service,
            body: body
        )

        var request = URLRequest(url: URL(string: "https://\(host)\(uri)?\(queryString)")!)
        request.httpMethod = "POST"
        request.httpBody = body
        request.timeoutInterval = 30
        for (field, value) in headers.dictionary where field != "Host" {
            request.setValue(value, forHTTPHeaderField: field)
        }

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 30
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EngineError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let text = String(data: data, encoding: .utf8) ?? ""
            throw EngineError.http(
                status: httpResponse.statusCode,
                body: String(text.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        if let error = decoded.responseMetadata?.error, let message = error.message {
            throw EngineError.http(status: 200, body: message)
        }
        guard let list = decoded.translationList else {
            throw EngineError.missingContent
        }

        var results: [Int: String] = [:]
        for (offset, entry) in batch.enumerated() {
            try Task.checkCancellation()
            guard offset < list.count, let translation = list[offset].translation,
                  !translation.isEmpty else {
                continue
            }
            let insertion = InsertionHTML.fromPlainText(translation)
            results[entry.index] = insertion
            onSegment(entry.index, insertion)
        }
        return results
    }
}
