import Foundation

/// 一个待翻译分段：原始 HTML + 纯文本两种形态，引擎按需取用。
struct TranslationInput: Sendable {
    let index: Int
    let html: String
    let plainText: String
}

enum EngineError: LocalizedError {
    case notConfigured(String)
    case invalidResponse
    case http(status: Int, body: String)
    case missingContent
    case unsupported(String)

    var errorDescription: String? {
        switch self {
        case .notConfigured(let hint): return hint
        case .invalidResponse: return "服务返回了无效的响应"
        case .http(let status, let body):
            return body.isEmpty ? "HTTP \(status)" : "HTTP \(status)：\(body)"
        case .missingContent: return "服务响应缺少翻译内容"
        case .unsupported(let message): return message
        }
    }
}

/// 翻译引擎协议：一次处理一个批次，渐进回调单段结果。
/// onSegment 回调的是"可直接插入邮件 HTML 的片段"（引擎自行做转义/标签处理）。
protocol TranslationEngine: Sendable {
    var kind: ProviderKind { get }
    /// 建议的批字符上限（不同引擎的性价比甜点不同）。
    var batchCharacterLimit: Int { get }
    /// 建议并发批次数。
    var maxConcurrentBatches: Int { get }

    func translate(
        batch: [TranslationInput],
        target: TargetLanguage,
        onSegment: @Sendable (Int, String) -> Void
    ) async throws -> [Int: String]
}

extension TranslationEngine {
    var batchCharacterLimit: Int { 4000 }
    var maxConcurrentBatches: Int { 4 }
}

/// 把纯文本译文转成可插入的 HTML 片段（转义实体、换行转 <br>）。
enum InsertionHTML {
    static func fromPlainText(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
        return escaped
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
            .replacingOccurrences(of: "\n", with: "<br>")
    }
}
