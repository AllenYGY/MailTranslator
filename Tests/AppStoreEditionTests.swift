import Foundation
import Darwin

@main
struct AppStoreEditionTests {
    static func main() throws {
        var failures = 0
        func expect(_ value: Bool, _ message: String) {
            if !value { failures += 1; fputs("FAIL: \(message)\n", stderr) }
        }
        expect(ProviderKind.allCases == [.apple], "Store edition exposes Apple Translation only")
        expect(TranslatorConfig.default.providerKind == .apple, "Default engine must be Apple")
        let old = Data("""
        {"targetLanguage":"en","activeProvider":"volcengine", "llmProfiles":
        {"custom":{"baseURL":"https://example.invalid","apiKey":"test-only-key","model":"test"}},
        "volcengine":{"accessKeyID":"test-ak","secretAccessKey":"test-sk"}}
        """.utf8)
        let migrated = try JSONDecoder().decode(TranslatorConfig.self, from: old)
        expect(migrated.providerKind == .apple, "Legacy cloud provider must not activate")
        expect(migrated.targetLanguage == "en", "Keep the user's target language")
        let saved = String(decoding: try JSONEncoder().encode(migrated), as: UTF8.self)
        for token in ["apiKey", "baseURL", "llmProfiles", "volcengine", "test-only-key"] {
            expect(!saved.contains(token), "Store config must not retain cloud fields: \(token)")
        }
        let prior = getenv("MT_PROVIDER").map { String(cString: $0) }
        defer {
            if let prior { setenv("MT_PROVIDER", prior, 1) } else { unsetenv("MT_PROVIDER") }
        }
        for override in ["dummy", "openai-compatible", "volcengine"] {
            setenv("MT_PROVIDER", override, 1)
            expect(Settings.current.providerKind == .apple, "Environment cannot change Store engine")
            expect(try EngineFactory.makeEngine(config: migrated) is AppleTranslationEngine,
                   "Factory cannot construct a non-Apple engine")
        }
        guard failures == 0 else { exit(1) }
        print("App Store edition isolation tests passed")
    }
}
