import Foundation

enum APIEndpointError: LocalizedError, Equatable {
    case invalidAddress
    case insecureRemoteHTTP

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            return "API 地址无效，请填写完整的 http:// 或 https:// 地址"
        case .insecureRemoteHTTP:
            return "远程 API 必须使用 HTTPS；HTTP 仅允许回环地址或私网 IPv4 地址"
        }
    }
}

/// OpenAI 兼容端点地址规范化（改编自 mailTranslatePlugin，MIT）。
enum APIEndpoint {
    static func url(from baseURL: String) throws -> URL {
        try endpointURL(from: baseURL, suffix: "/chat/completions")
    }

    static func modelsURL(from baseURL: String) throws -> URL {
        try endpointURL(from: baseURL, suffix: "/models")
    }

    private static func endpointURL(from baseURL: String, suffix: String) throws -> URL {
        let normalized = baseURL.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: normalized),
              let scheme = components.scheme?.lowercased(),
              scheme == "http" || scheme == "https",
              let host = components.host,
              !host.isEmpty else {
            throw APIEndpointError.invalidAddress
        }
        if scheme == "http" && !allowsInsecureHTTP(host) {
            throw APIEndpointError.insecureRemoteHTTP
        }

        var path = components.percentEncodedPath
        while path.hasSuffix("/") {
            path.removeLast()
        }
        for knownSuffix in ["/chat/completions", "/models"] where path.hasSuffix(knownSuffix) {
            path.removeLast(knownSuffix.count)
            break
        }
        components.percentEncodedPath = path + suffix
        components.fragment = nil
        guard let url = components.url else {
            throw APIEndpointError.invalidAddress
        }
        return url
    }

    private static func allowsInsecureHTTP(_ host: String) -> Bool {
        let normalized = host
            .trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
            .lowercased()
        if normalized == "localhost" || normalized == "::1" {
            return true
        }

        let octets = normalized.split(separator: ".", omittingEmptySubsequences: false)
        guard octets.count == 4,
              let first = ipv4Octet(octets[0]),
              let second = ipv4Octet(octets[1]),
              ipv4Octet(octets[2]) != nil,
              ipv4Octet(octets[3]) != nil else {
            return false
        }

        return first == 127
            || first == 10
            || (first == 172 && (16...31).contains(second))
            || (first == 192 && second == 168)
    }

    private static func ipv4Octet(_ octet: Substring) -> UInt8? {
        guard !octet.isEmpty, octet.count <= 3,
              octet.unicodeScalars.allSatisfy({ (48...57).contains($0.value) }) else {
            return nil
        }
        return UInt8(octet)
    }
}
