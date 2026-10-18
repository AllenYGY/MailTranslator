import Foundation

enum SharedConfiguration {
    static let groupIdentifier = "group.io.github.allenygy.mailtranslator"

    enum AccessError: LocalizedError {
        case unavailable

        var errorDescription: String? {
            "无法访问共享配置容器，请检查 App Group 签名权限"
        }
    }

    static func url(in container: URL?) throws -> URL {
        guard let container else { throw AccessError.unavailable }
        return ConfigFile.url(inApplicationSupport:
            container.appendingPathComponent("Library/Application Support", isDirectory: true)
        )
    }

    static func url() throws -> URL {
        try url(in: FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: groupIdentifier
        ))
    }
}
