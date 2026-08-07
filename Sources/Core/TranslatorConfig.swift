import Foundation

enum ProviderKind: String, Codable, CaseIterable {
    case openAICompatible = "openai-compatible"
    case volcengine
    case apple

    var displayName: String {
        switch self {
        case .openAICompatible: return "OpenAI 兼容 LLM"
        case .volcengine: return "火山翻译"
        case .apple: return "Apple 系统翻译"
        }
    }
}

struct OpenAIProviderConfig: Codable, Equatable {
    var baseURL: String
    var model: String
    var apiKey: String
    var modelCatalog: [String]

    private enum CodingKeys: String, CodingKey {
        case baseURL
        case model
        case apiKey
        case modelCatalog
    }

    init(
        baseURL: String = "",
        model: String = "",
        apiKey: String = "",
        modelCatalog: [String] = []
    ) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.modelCatalog = modelCatalog
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        baseURL = try container.decodeIfPresent(String.self, forKey: .baseURL) ?? ""
        model = try container.decodeIfPresent(String.self, forKey: .model) ?? ""
        apiKey = try container.decodeIfPresent(String.self, forKey: .apiKey) ?? ""
        modelCatalog = try container.decodeIfPresent([String].self, forKey: .modelCatalog) ?? []
    }

    var isConfigured: Bool {
        !baseURL.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !model.isEmpty
    }
}

struct VolcengineProviderConfig: Codable, Equatable {
    var accessKeyID: String = ""
    var secretAccessKey: String = ""

    var isConfigured: Bool {
        !accessKeyID.isEmpty && !secretAccessKey.isEmpty
    }
}

struct TranslatorConfig: Codable, Equatable {
    var targetLanguage: String = TargetLanguage.zhHans.rawValue
    var activeProvider: String = ProviderKind.openAICompatible.rawValue
    var activeLLMPresetRawValue: String = LLMProviderPreset.openAI.rawValue
    var llmProfiles: [String: OpenAIProviderConfig] = [:]
    var volcengine: VolcengineProviderConfig = VolcengineProviderConfig()

    static let `default` = TranslatorConfig()

    private enum CodingKeys: String, CodingKey {
        case targetLanguage
        case activeProvider
        case activeLLMPresetRawValue = "activeLLMPreset"
        case llmProfiles
        case openAI
        case volcengine
    }

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        targetLanguage = try container.decodeIfPresent(String.self, forKey: .targetLanguage)
            ?? TargetLanguage.zhHans.rawValue
        activeProvider = try container.decodeIfPresent(String.self, forKey: .activeProvider)
            ?? ProviderKind.openAICompatible.rawValue
        activeLLMPresetRawValue = try container.decodeIfPresent(
            String.self,
            forKey: .activeLLMPresetRawValue
        ) ?? LLMProviderPreset.openAI.rawValue
        llmProfiles = try container.decodeIfPresent(
            [String: OpenAIProviderConfig].self,
            forKey: .llmProfiles
        ) ?? [:]
        volcengine = try container.decodeIfPresent(
            VolcengineProviderConfig.self,
            forKey: .volcengine
        ) ?? VolcengineProviderConfig()

        // Older releases stored one shared `openAI` object. Preserve it under
        // the preset matching its address, without writing that legacy field back.
        if let legacy = try container.decodeIfPresent(OpenAIProviderConfig.self, forKey: .openAI),
           legacy.hasAnyValue {
            let migratedPreset = LLMProviderPreset.matching(baseURL: legacy.baseURL)
            if llmProfiles[migratedPreset.rawValue] == nil {
                llmProfiles[migratedPreset.rawValue] = legacy
            }
            if !container.contains(.activeLLMPresetRawValue) {
                activeLLMPresetRawValue = migratedPreset.rawValue
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(targetLanguage, forKey: .targetLanguage)
        try container.encode(activeProvider, forKey: .activeProvider)
        try container.encode(activeLLMPresetRawValue, forKey: .activeLLMPresetRawValue)
        try container.encode(llmProfiles, forKey: .llmProfiles)
        try container.encode(volcengine, forKey: .volcengine)
    }

    var providerKind: ProviderKind {
        ProviderKind(rawValue: activeProvider) ?? .openAICompatible
    }

    var activeLLMPreset: LLMProviderPreset {
        get {
            LLMProviderPreset(rawValue: activeLLMPresetRawValue) ?? .custom
        }
        set {
            activeLLMPresetRawValue = newValue.rawValue
        }
    }

    var activeLLMProfile: OpenAIProviderConfig {
        llmProfiles[activeLLMPreset.rawValue]
            ?? OpenAIProviderConfig(baseURL: activeLLMPreset.baseURL ?? "")
    }

    func llmProfile(for preset: LLMProviderPreset) -> OpenAIProviderConfig {
        llmProfiles[preset.rawValue]
            ?? OpenAIProviderConfig(baseURL: preset.baseURL ?? "")
    }

    mutating func setActiveLLMProfile(_ profile: OpenAIProviderConfig) {
        llmProfiles[activeLLMPreset.rawValue] = profile
    }

    mutating func setActiveLLMProfile(
        _ profile: OpenAIProviderConfig,
        for preset: LLMProviderPreset
    ) {
        llmProfiles[preset.rawValue] = profile
    }

    var target: TargetLanguage {
        TargetLanguage(rawValue: targetLanguage) ?? .zhHans
    }

    func isActiveProviderConfigured() -> Bool {
        switch providerKind {
        case .openAICompatible: return activeLLMProfile.isConfigured
        case .volcengine: return volcengine.isConfigured
        case .apple: return true
        }
    }
}

private extension OpenAIProviderConfig {
    var hasAnyValue: Bool {
        !baseURL.isEmpty || !model.isEmpty || !apiKey.isEmpty
    }
}
