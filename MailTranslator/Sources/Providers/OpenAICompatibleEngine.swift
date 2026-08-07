import Foundation

/// LLM 响应流里逐段解析 @@编号@@ 标记：一段闭合即回调，不必等整个响应结束。
struct MarkerStreamParser {
    private var buffer = ""
    private var pending: Int?

    mutating func append(_ delta: String) -> [(Int, String)] {
        buffer += delta
        return drain(flush: false)
    }

    mutating func finish() -> [(Int, String)] {
        drain(flush: true)
    }

    private mutating func drain(flush: Bool) -> [(Int, String)] {
        var results: [(Int, String)] = []
        while true {
            if pending == nil {
                guard let marker = nextMarkerLine() else {
                    // 模型未按约定输出标记时防止缓冲无限增长。
                    if buffer.count > 64_000 {
                        buffer = String(buffer.suffix(4_000))
                    }
                    break
                }
                pending = marker.index
                buffer = String(buffer[marker.afterLine...])
                continue
            }
            guard let marker = nextMarkerLine() else { break }
            let content = String(buffer[..<marker.lineStart])
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if let index = pending, !content.isEmpty {
                results.append((index, content))
            }
            pending = marker.index
            buffer = String(buffer[marker.afterLine...])
        }
        if flush, let index = pending {
            let content = buffer.trimmingCharacters(in: .whitespacesAndNewlines)
            if !content.isEmpty {
                results.append((index, content))
            }
            pending = nil
            buffer = ""
        }
        return results
    }

    private func nextMarkerLine() -> (index: Int, lineStart: String.Index, afterLine: String.Index)? {
        var lineStart = buffer.startIndex
        while lineStart < buffer.endIndex {
            guard let newline = buffer[lineStart...].firstIndex(of: "\n") else {
                return nil
            }
            if let index = Self.parseMarker(buffer[lineStart..<newline]) {
                return (index, lineStart, buffer.index(after: newline))
            }
            lineStart = buffer.index(after: newline)
        }
        return nil
    }

    static func parseMarker(_ line: Substring) -> Int? {
        let trimmed = line.trimmingCharacters(in: CharacterSet(charactersIn: " \t\r"))
        guard trimmed.hasPrefix("@@"), trimmed.hasSuffix("@@"), trimmed.count > 4 else {
            return nil
        }
        let digits = trimmed.dropFirst(2).dropLast(2)
        guard digits.allSatisfy({ $0.isNumber }) else { return nil }
        return Int(digits)
    }
}

/// OpenAI 兼容 LLM 引擎：/v1/chat/completions + SSE 流式。
struct OpenAICompatibleEngine: TranslationEngine {
    let config: OpenAIProviderConfig

    var kind: ProviderKind { .openAICompatible }
    var maxConcurrentBatches: Int { 3 }

    private struct Message: Encodable {
        let role: String
        let content: String
    }

    private struct RequestBody: Encodable {
        let model: String
        let messages: [Message]
        let temperature: Double
        let stream: Bool
    }

    private struct StreamChunk: Decodable {
        struct Choice: Decodable {
            struct Delta: Decodable {
                let content: String?
            }
            let delta: Delta?
        }
        let choices: [Choice]
    }

    private struct ResponseBody: Decodable {
        struct Choice: Decodable {
            struct ResponseMessage: Decodable {
                let content: String
            }
            let message: ResponseMessage
        }
        let choices: [Choice]
    }

    private func systemPrompt(target: TargetLanguage) -> String {
        "你是专业的邮件翻译助手。用户消息包含若干段带编号的邮件内容，每段以单独一行 @@数字@@ 开头。"
        + "把每段翻译成\(target.promptName)，要求："
        + "1) 逐段输出译文，每段译文前保留与原文完全相同的 @@数字@@ 标记行，标记数量与编号必须一一对应，不得增减；"
        + "2) 段内的 HTML 标签及其属性（如 <a href=\"…\">、<b>、<span style=\"…\">、<img …>）原样保留，只翻译标签之外的可见文字；"
        + "3) HTML 实体（如 &amp;、&nbsp;）原样保留；"
        + "4) 人名、公司名、产品名、URL、邮箱地址、代码保持原样不译；"
        + "5) 只输出标记行和译文，不要任何解释。"
    }

    func translate(
        batch: [TranslationInput],
        target: TargetLanguage,
        onSegment: @Sendable (Int, String) -> Void
    ) async throws -> [Int: String] {
        try Task.checkCancellation()
        let endpoint = try APIEndpoint.url(from: config.baseURL)
        let payload = HTMLSegments.payload(
            for: batch.map { (index: $0.index, html: $0.html) }
        )

        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 90
        configuration.timeoutIntervalForResource = 300
        let session = URLSession(configuration: configuration)
        defer { session.invalidateAndCancel() }

        var results: [Int: String] = [:]
        let streamed = try await streamingTranslate(
            payload: payload,
            target: target,
            endpoint: endpoint,
            session: session,
            onSegment: { index, translation in
                onSegment(index, translation)
            }
        )
        try Task.checkCancellation()
        results.merge(streamed) { _, new in new }

        // 流式没拿到的段（模型漏标记/截断），非流式补一次。
        let missing = batch.filter { results[$0.index] == nil }
        if !missing.isEmpty {
            try Task.checkCancellation()
            let retryPayload = HTMLSegments.payload(
                for: missing.map { (index: $0.index, html: $0.html) }
            )
            let retried = try await blockingTranslate(
                payload: retryPayload,
                target: target,
                endpoint: endpoint,
                session: session
            )
            try Task.checkCancellation()
            let parsed = HTMLSegments.parseResponse(retried)
            for entry in missing {
                try Task.checkCancellation()
                if let translation = parsed[entry.index] {
                    results[entry.index] = translation
                    onSegment(entry.index, translation)
                }
            }
        }
        return results
    }

    private func makeRequest(
        endpoint: URL,
        payload: String,
        target: TargetLanguage,
        stream: Bool
    ) throws -> URLRequest {
        var request = URLRequest(url: endpoint)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !config.apiKey.isEmpty {
            request.setValue("Bearer \(config.apiKey)", forHTTPHeaderField: "Authorization")
        }
        request.httpBody = try JSONEncoder().encode(
            RequestBody(
                model: config.model,
                messages: [
                    Message(role: "system", content: systemPrompt(target: target)),
                    Message(role: "user", content: payload),
                ],
                temperature: 0.2,
                stream: stream
            )
        )
        return request
    }

    private func streamingTranslate(
        payload: String,
        target: TargetLanguage,
        endpoint: URL,
        session: URLSession,
        onSegment: @Sendable (Int, String) -> Void
    ) async throws -> [Int: String] {
        let request = try makeRequest(endpoint: endpoint, payload: payload, target: target, stream: true)
        let (bytes, response) = try await session.bytes(for: request)
        try Task.checkCancellation()
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EngineError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            var body = ""
            for try await line in bytes.lines {
                body += line
                if body.count > 400 { break }
            }
            throw EngineError.http(
                status: httpResponse.statusCode,
                body: String(body.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        var parser = MarkerStreamParser()
        var results: [Int: String] = [:]
        for try await line in bytes.lines {
            try Task.checkCancellation()
            guard line.hasPrefix("data:") else { continue }
            let data = line.dropFirst(5).trimmingCharacters(in: .whitespaces)
            if data == "[DONE]" { break }
            guard let chunk = try? JSONDecoder().decode(StreamChunk.self, from: Data(data.utf8)),
                  let delta = chunk.choices.first?.delta?.content,
                  !delta.isEmpty else {
                continue
            }
            for (index, translation) in parser.append(delta) {
                try Task.checkCancellation()
                results[index] = translation
                onSegment(index, translation)
            }
        }
        for (index, translation) in parser.finish() {
            try Task.checkCancellation()
            results[index] = translation
            onSegment(index, translation)
        }
        return results
    }

    private func blockingTranslate(
        payload: String,
        target: TargetLanguage,
        endpoint: URL,
        session: URLSession
    ) async throws -> String {
        let request = try makeRequest(endpoint: endpoint, payload: payload, target: target, stream: false)
        let (data, response) = try await session.data(for: request)
        try Task.checkCancellation()
        guard let httpResponse = response as? HTTPURLResponse else {
            throw EngineError.invalidResponse
        }
        guard (200..<300).contains(httpResponse.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw EngineError.http(
                status: httpResponse.statusCode,
                body: String(body.prefix(200)).trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }
        let decoded = try JSONDecoder().decode(ResponseBody.self, from: data)
        guard let content = decoded.choices.first?.message.content else {
            throw EngineError.missingContent
        }
        return content
    }
}
