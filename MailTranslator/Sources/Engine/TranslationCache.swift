import CryptoKit
import Foundation

/// 磁盘缓存：message-id + 引擎 + 目标语言 → 单段译文，重开邮件秒出。
final class TranslationCache: @unchecked Sendable {
    struct Entry: Codable {
        let provider: String
        let targetLanguage: String
        let translations: [String: String]
    }

    private let directory: URL
    private let lock = NSLock()

    init(directory: URL) {
        self.directory = directory
    }

    static func cacheKey(messageKey: String, provider: String, target: String) -> String {
        let raw = "\(provider)|\(target)|\(messageKey)"
        return SHA256.hash(data: Data(raw.utf8)).map { String(format: "%02x", $0) }.joined()
    }

    func load(key: String) -> [Int: String]? {
        lock.lock()
        defer { lock.unlock() }
        let url = directory.appendingPathComponent("\(key).json")
        guard let entry: Entry = ConfigFile.load(Entry.self, from: url) else {
            return nil
        }
        var result: [Int: String] = [:]
        for (indexString, translation) in entry.translations {
            if let index = Int(indexString) {
                result[index] = translation
            }
        }
        return result.isEmpty ? nil : result
    }

    func save(key: String, provider: String, target: String, translations: [Int: String]) {
        guard !translations.isEmpty else { return }
        lock.lock()
        defer { lock.unlock() }
        var stringKeyed: [String: String] = [:]
        for (index, translation) in translations {
            stringKeyed[String(index)] = translation
        }
        let entry = Entry(provider: provider, targetLanguage: target, translations: stringKeyed)
        let url = directory.appendingPathComponent("\(key).json")
        try? ConfigFile.save(entry, to: url)
    }
}
