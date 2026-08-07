import Foundation
import NaturalLanguage

enum TargetLanguage: String, Codable, CaseIterable {
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case en
    case ja
    case ko
    case fr
    case de
    case es
    case ru

    var displayName: String {
        switch self {
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .en: return "English"
        case .ja: return "日本語"
        case .ko: return "한국어"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .es: return "Español"
        case .ru: return "Русский"
        }
    }

    /// LLM prompt 中使用的语言名。
    var promptName: String {
        switch self {
        case .zhHans: return "简体中文"
        case .zhHant: return "繁體中文"
        case .en: return "English"
        case .ja: return "Japanese"
        case .ko: return "Korean"
        case .fr: return "French"
        case .de: return "German"
        case .es: return "Spanish"
        case .ru: return "Russian"
        }
    }

    /// 火山翻译语言代码。
    var volcCode: String {
        switch self {
        case .zhHans, .zhHant: return "zh"
        case .en: return "en"
        case .ja: return "ja"
        case .ko: return "ko"
        case .fr: return "fr"
        case .de: return "de"
        case .es: return "es"
        case .ru: return "ru"
        }
    }

    /// Apple Translation 框架的 Locale.Language。
    var localeLanguage: Locale.Language {
        switch self {
        case .zhHans: return Locale.Language(identifier: "zh-Hans")
        case .zhHant: return Locale.Language(identifier: "zh-Hant")
        case .en: return Locale.Language(identifier: "en")
        case .ja: return Locale.Language(identifier: "ja")
        case .ko: return Locale.Language(identifier: "ko")
        case .fr: return Locale.Language(identifier: "fr")
        case .de: return Locale.Language(identifier: "de")
        case .es: return Locale.Language(identifier: "es")
        case .ru: return Locale.Language(identifier: "ru")
        }
    }

    /// 用于判断"邮件已经是目标语言、无需翻译"的 NL 语言集合。
    var equivalentNLLanguages: Set<NLLanguage> {
        switch self {
        case .zhHans, .zhHant: return [.simplifiedChinese, .traditionalChinese]
        case .en: return [.english]
        case .ja: return [.japanese]
        case .ko: return [.korean]
        case .fr: return [.french]
        case .de: return [.german]
        case .es: return [.spanish]
        case .ru: return [.russian]
        }
    }
}

enum LanguageDetector {
    /// 正文是否值得翻译：够长且主导语言不是目标语言。
    static func needsTranslation(_ plainText: String, target: TargetLanguage) -> Bool {
        guard plainText.count >= 40 else { return false }
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(plainText)
        guard let language = recognizer.dominantLanguage else { return false }
        return !target.equivalentNLLanguages.contains(language)
    }
}
