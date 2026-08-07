import Foundation

enum OpenAIModelCatalogError: LocalizedError {
    case invalidResponse
    case empty
    case http(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "模型列表格式不兼容，请手动输入模型名称"
        case .empty:
            return "服务没有返回可用模型，请手动输入模型名称"
        case let .http(status, message):
            let detail = message.isEmpty ? "请检查 API 地址和密钥" : message
            return "获取模型失败（HTTP \(status)）：\(detail)"
        }
    }
}

struct OpenAIModelCatalog {
    private struct ModelList: Decodable {
        struct Model: Decodable {
            let id: String
        }

        let data: [Model]
    }

    private struct ErrorEnvelope: Decodable {
        struct ErrorDetail: Decodable {
            let message: String
        }

        let error: ErrorDetail
    }

    let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    static func makeRequest(baseURL: String, apiKey: String) throws -> URLRequest {
        var request = URLRequest(
            url: try APIEndpoint.modelsURL(from: baseURL),
            cachePolicy: .reloadIgnoringLocalCacheData,
            timeoutInterval: 30
        )
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let trimmedKey = apiKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedKey.isEmpty {
            request.setValue("Bearer \(trimmedKey)", forHTTPHeaderField: "Authorization")
        }
        return request
    }

    static func decodeModels(from data: Data) throws -> [String] {
        guard let response = try? JSONDecoder().decode(ModelList.self, from: data) else {
            throw OpenAIModelCatalogError.invalidResponse
        }
        let models = Set(response.data.compactMap { model -> String? in
            let id = model.id.trimmingCharacters(in: .whitespacesAndNewlines)
            return id.isEmpty ? nil : id
        }).sorted { $0.localizedStandardCompare($1) == .orderedAscending }
        guard !models.isEmpty else {
            throw OpenAIModelCatalogError.empty
        }
        return models
    }

    static func validate(data: Data, response: URLResponse) throws -> [String] {
        guard let httpResponse = response as? HTTPURLResponse else {
            throw OpenAIModelCatalogError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let structured = try? JSONDecoder().decode(ErrorEnvelope.self, from: data)
            let raw = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let message = structured?.error.message ?? String(raw.prefix(200))
            throw OpenAIModelCatalogError.http(
                status: httpResponse.statusCode,
                message: message
            )
        }
        return try decodeModels(from: data)
    }

    func fetch(baseURL: String, apiKey: String) async throws -> [String] {
        let request = try Self.makeRequest(baseURL: baseURL, apiKey: apiKey)
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        return try Self.validate(data: data, response: response)
    }
}
