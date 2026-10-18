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

}
