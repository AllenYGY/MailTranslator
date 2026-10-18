import Foundation

enum ProviderKind: String, Codable, CaseIterable {
    case apple
    var displayName: String { "Apple 系统翻译" }
}

struct TranslatorConfig: Codable, Equatable {
    var targetLanguage = TargetLanguage.zhHans.rawValue
    static let `default` = TranslatorConfig()

    private enum CodingKeys: String, CodingKey { case targetLanguage }

    init() {}

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        targetLanguage = try values.decodeIfPresent(String.self, forKey: .targetLanguage)
            ?? TargetLanguage.zhHans.rawValue
    }

    // Decode only language: legacy credentials never enter Store configuration.
    var providerKind: ProviderKind { .apple }
    var target: TargetLanguage { TargetLanguage(rawValue: targetLanguage) ?? .zhHans }
    func isActiveProviderConfigured() -> Bool { true }
}
