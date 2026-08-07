import Foundation

enum EngineFactory {
    static func makeEngine(config: TranslatorConfig) throws -> TranslationEngine {
        // 开发自测：MT_PROVIDER=dummy 走离线假引擎，验证管线与拼装。
        if ProcessInfo.processInfo.environment["MT_PROVIDER"] == "dummy" {
            return DummyEngine()
        }
        switch config.providerKind {
        case .openAICompatible:
            guard config.activeLLMProfile.isConfigured else {
                throw EngineError.notConfigured("请打开 MailTranslator 应用配置 OpenAI 兼容 API")
            }
            return OpenAICompatibleEngine(config: config.activeLLMProfile)
        case .volcengine:
            guard config.volcengine.isConfigured else {
                throw EngineError.notConfigured("请打开 MailTranslator 应用配置火山翻译密钥")
            }
            return VolcengineEngine(config: config.volcengine)
        case .apple:
            return AppleTranslationEngine()
        }
    }
}

/// 离线自测引擎：不联网，给每段加上"[译]"前缀。
struct DummyEngine: TranslationEngine {
    var kind: ProviderKind { .apple }
    var batchCharacterLimit: Int { 800 }
    var maxConcurrentBatches: Int { 4 }

    func translate(
        batch: [TranslationInput],
        target: TargetLanguage,
        onSegment: @Sendable (Int, String) -> Void
    ) async throws -> [Int: String] {
        try await Task.sleep(nanoseconds: 200_000_000)
        var results: [Int: String] = [:]
        for entry in batch {
            let insertion = InsertionHTML.fromPlainText("[译] \(entry.plainText)")
            results[entry.index] = insertion
            onSegment(entry.index, insertion)
        }
        return results
    }
}
