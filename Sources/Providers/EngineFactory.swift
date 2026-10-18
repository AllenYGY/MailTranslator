import Foundation

enum EngineFactory {
    static func makeEngine(config: TranslatorConfig) throws -> TranslationEngine {
        AppleTranslationEngine()
    }
}
