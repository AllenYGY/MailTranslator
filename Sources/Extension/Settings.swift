import Foundation

/// 扩展侧配置读取：配置文件存于扩展沙盒容器，宿主 App 写入，扩展按 mtime 热加载。
enum Settings {
    static let extensionBundleID = BundleID.extension_

    private static let lock = NSLock()
    private static var cache: (config: TranslatorConfig, mtime: Date?)?
    private static let legacyFileURL = ConfigFile.url(
        inApplicationSupport: FileManager.default.urls(
            for: .applicationSupportDirectory, in: .userDomainMask
        )[0]
    )

    private static var fileURL: URL? {
        #if APP_STORE
        guard let shared = try? SharedConfiguration.url() else { return nil }
        // The extension can migrate its own container without host access to it.
        if !FileManager.default.fileExists(atPath: shared.path),
           let legacy = ConfigFile.load(TranslatorConfig.self, from: legacyFileURL) {
            try? ConfigFile.save(legacy, to: shared)
        }
        return shared
        #else
        return legacyFileURL
        #endif
    }

    static var current: TranslatorConfig {
        if let override = environmentConfig() {
            return override
        }
        lock.lock()
        defer { lock.unlock() }
        guard let fileURL else { return .default }
        let mtime = ConfigFile.modificationDate(of: fileURL)
        if let cache, cache.mtime == mtime {
            return cache.config
        }
        let config = ConfigFile.load(TranslatorConfig.self, from: fileURL) ?? .default
        cache = (config, mtime)
        return config
    }

    static var cacheDirectory: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("MailTranslator/cache")
    }

    /// 命令行/调试用环境变量覆盖（tmtest）。
    private static func environmentConfig() -> TranslatorConfig? {
        let env = ProcessInfo.processInfo.environment
        guard env["MT_PROVIDER"] != nil || env["MT_API_BASE"] != nil else {
            return nil
        }
        var config = TranslatorConfig.default
        if let provider = env["MT_PROVIDER"] {
            config.activeProvider = provider
        }
        if let target = env["MT_TARGET"] {
            config.targetLanguage = target
        }
        var llmProfile = config.activeLLMProfile
        if let base = env["MT_API_BASE"] { llmProfile.baseURL = base }
        if let model = env["MT_MODEL"] { llmProfile.model = model }
        if let key = env["MT_API_KEY"] { llmProfile.apiKey = key }
        config.setActiveLLMProfile(llmProfile)
        if let ak = env["MT_VOLC_AK"] { config.volcengine.accessKeyID = ak }
        if let sk = env["MT_VOLC_SK"] { config.volcengine.secretAccessKey = sk }
        return config
    }
}
