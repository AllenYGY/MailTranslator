import Foundation

enum LLMProviderPreset: String, CaseIterable {
    case openAI
    case deepSeek
    case kimi
    case dashScope
    case volcengineArk
    case ollama
    case custom

    var displayName: String {
        switch self {
        case .openAI: return "OpenAI"
        case .deepSeek: return "DeepSeek"
        case .kimi: return "Kimi"
        case .dashScope: return "通义千问"
        case .volcengineArk: return "豆包（火山方舟）"
        case .ollama: return "Ollama（本机）"
        case .custom: return "自定义"
        }
    }

    var baseURL: String? {
        switch self {
        case .openAI: return "https://api.openai.com/v1"
        case .deepSeek: return "https://api.deepseek.com"
        case .kimi: return "https://api.moonshot.cn/v1"
        case .dashScope: return "https://dashscope.aliyuncs.com/compatible-mode/v1"
        case .volcengineArk: return "https://ark.cn-beijing.volces.com/api/v3"
        case .ollama: return "http://localhost:11434/v1"
        case .custom: return nil
        }
    }

    var hasDocumentedModelCatalog: Bool {
        switch self {
        case .dashScope, .volcengineArk, .custom:
            return false
        case .openAI, .deepSeek, .kimi, .ollama:
            return true
        }
    }

    static func matching(baseURL: String) -> LLMProviderPreset {
        guard let normalized = try? APIEndpoint.url(from: baseURL).absoluteString else {
            return .custom
        }
        return allCases.first { preset in
            guard let presetURL = preset.baseURL,
                  let candidate = try? APIEndpoint.url(from: presetURL).absoluteString else {
                return false
            }
            return candidate == normalized
        } ?? .custom
    }
}
