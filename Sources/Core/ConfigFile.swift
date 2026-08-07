import Foundation

/// 通用 Codable JSON 配置文件读写（原子写入、0600 权限）。
enum ConfigFile {
    static let relativePath = "MailTranslator/config.json"

    static func url(inApplicationSupport dir: URL) -> URL {
        dir.appendingPathComponent(relativePath)
    }

    static func load<T: Decodable>(_ type: T.Type, from url: URL) -> T? {
        guard let data = try? Data(contentsOf: url) else {
            return nil
        }
        try? securePermissions(of: url)
        return try? JSONDecoder().decode(T.self, from: data)
    }

    static func save<T: Encodable>(_ value: T, to url: URL) throws {
        try FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(value)
        try data.write(to: url, options: .atomic)
        try securePermissions(of: url)
    }

    static func modificationDate(of url: URL) -> Date? {
        let attributes = try? FileManager.default.attributesOfItem(atPath: url.path)
        return attributes?[.modificationDate] as? Date
    }

    private static func securePermissions(of url: URL) throws {
        try FileManager.default.setAttributes(
            [.posixPermissions: 0o600],
            ofItemAtPath: url.path
        )
    }
}
