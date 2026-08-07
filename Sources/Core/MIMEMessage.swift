import CoreFoundation
import Foundation

struct MIMEMessage {
    struct Part {
        let headerRange: Range<Int>
        let bodyRange: Range<Int>
        let contentType: String
        let charset: String?
        let cte: String?
        let boundary: String?
        let children: [Part]
    }

    private struct HeaderBodySplit {
        let headerRange: Range<Int>
        let bodyRange: Range<Int>
        let eol: String
    }

    private struct BoundaryMarker {
        let start: Int
        let afterLine: Int
        let closing: Bool
    }

    private let data: Data
    private let root: Part?

    init(data: Data) {
        self.data = data
        root = Self.parsePart(in: 0..<data.count, data: data, depth: 0)
    }

    static func headerValue(_ name: String, in data: Data) -> String? {
        guard let split = splitHeaderBody(in: 0..<data.count, data: data) else {
            return nil
        }
        return headerValue(name, in: split.headerRange, data: data)
    }

    func displayPart() -> Part? {
        guard let root else { return nil }
        var htmlParts: [Part] = []
        var plainParts: [Part] = []

        func visit(_ part: Part) {
            if isAttachment(part) {
                return
            }
            if part.contentType == "text/html" {
                htmlParts.append(part)
            } else if part.contentType == "text/plain" {
                plainParts.append(part)
            }
            for child in part.children {
                visit(child)
            }
        }

        visit(root)
        return htmlParts.first ?? plainParts.first
    }

    static func decodeBody(_ data: Data, cte: String?, charset: String?) -> String? {
        let decoded: Data
        switch cte?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() ?? "7bit" {
        case "7bit", "8bit", "binary", "":
            decoded = data
        case "base64":
            guard let value = Data(base64Encoded: data, options: .ignoreUnknownCharacters) else {
                return nil
            }
            decoded = value
        case "quoted-printable":
            decoded = decodeQuotedPrintable(data)
        default:
            return nil
        }

        if let charset,
           let encoding = stringEncoding(forIANACharset: charset),
           let value = String(data: decoded, encoding: encoding) {
            return value
        }
        if let value = String(data: decoded, encoding: .utf8) {
            return value
        }
        return String(data: decoded, encoding: .isoLatin1)
    }


    static func replacing(part: Part, with body: Data, contentType: String, in data: Data) -> Data {
        let eol = lineEnding(for: part, in: data)
        let encodedBody = wrappedBase64(body, eol: eol)

        if part.headerRange.lowerBound == 0 {
            guard let split = splitHeaderBody(in: 0..<data.count, data: data) else {
                return data
            }
            let headers = rewritingTopLevelHeaders(
                data[split.headerRange],
                contentType: contentType,
                eol: split.eol
            )
            var result = Data()
            result.append(headers)
            result.append(Data((split.eol + split.eol).utf8))
            result.append(encodedBody)
            return result
        }

        var replacement = Data("Content-Type: \(contentType); charset=utf-8\(eol)".utf8)
        replacement.append(Data("Content-Transfer-Encoding: base64\(eol)\(eol)".utf8))
        replacement.append(encodedBody)

        var result = Data()
        result.append(data[..<part.headerRange.lowerBound])
        result.append(replacement)
        result.append(data[part.bodyRange.upperBound...])
        return result
    }

    private func isAttachment(_ part: Part) -> Bool {
        guard let disposition = Self.headerValue(
            "Content-Disposition",
            in: part.headerRange,
            data: data
        ) else {
            return false
        }
        return disposition
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() == "attachment"
    }

    private static func parsePart(in range: Range<Int>, data: Data, depth: Int) -> Part? {
        guard let split = splitHeaderBody(in: range, data: data) else {
            return nil
        }

        let contentTypeHeader = headerValue("Content-Type", in: split.headerRange, data: data) ?? "text/plain"
        let contentType = mediaType(from: contentTypeHeader)
        let parameters = mediaTypeParameters(from: contentTypeHeader)
        let charset = parameters["charset"]
        let boundary = parameters["boundary"]
        let cte = headerValue("Content-Transfer-Encoding", in: split.headerRange, data: data)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()

        var children: [Part] = []
        if depth < 8, contentType.hasPrefix("multipart/"), let boundary, !boundary.isEmpty {
            children = parseMultipartChildren(
                in: split.bodyRange,
                boundary: boundary,
                data: data,
                depth: depth + 1
            )
        }

        return Part(
            headerRange: split.headerRange,
            bodyRange: split.bodyRange,
            contentType: contentType,
            charset: charset,
            cte: cte,
            boundary: boundary,
            children: children
        )
    }

    private static func parseMultipartChildren(
        in bodyRange: Range<Int>,
        boundary: String,
        data: Data,
        depth: Int
    ) -> [Part] {
        let markers = boundaryMarkers(in: bodyRange, boundary: boundary, data: data)
        guard !markers.isEmpty else { return [] }

        var children: [Part] = []
        var childStart: Int?
        for marker in markers {
            if let start = childStart, marker.start > start,
               let child = parsePart(in: start..<marker.start, data: data, depth: depth) {
                children.append(child)
            }
            if marker.closing {
                childStart = nil
                break
            }
            childStart = marker.afterLine
        }

        if let start = childStart, start < bodyRange.upperBound,
           let child = parsePart(in: start..<bodyRange.upperBound, data: data, depth: depth) {
            children.append(child)
        }
        return children
    }

    private static func boundaryMarkers(
        in range: Range<Int>,
        boundary: String,
        data: Data
    ) -> [BoundaryMarker] {
        let prefix = Array("--\(boundary)".utf8)
        guard !prefix.isEmpty else { return [] }

        var markers: [BoundaryMarker] = []
        var lineStart = range.lowerBound
        while lineStart < range.upperBound {
            var newline = lineStart
            while newline < range.upperBound, data[newline] != 0x0A {
                newline += 1
            }
            var lineEnd = newline
            if lineEnd > lineStart, data[lineEnd - 1] == 0x0D {
                lineEnd -= 1
            }
            let afterLine = newline < range.upperBound ? newline + 1 : newline

            if lineEnd - lineStart >= prefix.count {
                var matches = true
                for (offset, byte) in prefix.enumerated() where data[lineStart + offset] != byte {
                    matches = false
                    break
                }
                if matches {
                    var cursor = lineStart + prefix.count
                    var closing = false
                    if cursor + 1 < lineEnd, data[cursor] == 0x2D, data[cursor + 1] == 0x2D {
                        closing = true
                        cursor += 2
                    }
                    while cursor < lineEnd, data[cursor] == 0x20 || data[cursor] == 0x09 {
                        cursor += 1
                    }
                    if cursor == lineEnd {
                        markers.append(BoundaryMarker(start: lineStart, afterLine: afterLine, closing: closing))
                    }
                }
            }
            lineStart = afterLine
        }
        return markers
    }

    private static func splitHeaderBody(in range: Range<Int>, data: Data) -> HeaderBodySplit? {
        if let separator = firstOccurrence(of: [0x0D, 0x0A, 0x0D, 0x0A], in: range, data: data) {
            return HeaderBodySplit(
                headerRange: range.lowerBound..<separator,
                bodyRange: (separator + 4)..<range.upperBound,
                eol: "\r\n"
            )
        }
        if let separator = firstOccurrence(of: [0x0A, 0x0A], in: range, data: data) {
            return HeaderBodySplit(
                headerRange: range.lowerBound..<separator,
                bodyRange: (separator + 2)..<range.upperBound,
                eol: "\n"
            )
        }
        return nil
    }

    private static func firstOccurrence(of needle: [UInt8], in range: Range<Int>, data: Data) -> Int? {
        guard !needle.isEmpty, range.count >= needle.count else { return nil }
        let lastStart = range.upperBound - needle.count
        var start = range.lowerBound
        while start <= lastStart {
            var matches = true
            for (offset, byte) in needle.enumerated() where data[start + offset] != byte {
                matches = false
                break
            }
            if matches { return start }
            start += 1
        }
        return nil
    }

    private static func headerValue(_ name: String, in range: Range<Int>, data: Data) -> String? {
        guard let raw = String(data: data[range], encoding: .isoLatin1) else {
            return nil
        }
        let normalized = raw.replacingOccurrences(of: "\r\n", with: "\n")
        let wanted = name.lowercased()
        var currentName: String?
        var currentValue = ""

        func matchedValue() -> String? {
            guard currentName == wanted else { return nil }
            return currentValue.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        for lineSlice in normalized.split(separator: "\n", omittingEmptySubsequences: false) {
            let line = String(lineSlice)
            if line.first == " " || line.first == "\t" {
                if currentName != nil {
                    currentValue += " " + line.trimmingCharacters(in: .whitespacesAndNewlines)
                }
                continue
            }
            if let value = matchedValue() {
                return value
            }
            guard let colon = line.firstIndex(of: ":") else {
                currentName = nil
                currentValue = ""
                continue
            }
            currentName = String(line[..<colon]).trimmingCharacters(in: .whitespaces).lowercased()
            currentValue = String(line[line.index(after: colon)...]).trimmingCharacters(in: .whitespaces)
        }
        return matchedValue()
    }

    private static func mediaType(from contentType: String) -> String {
        contentType
            .split(separator: ";", maxSplits: 1, omittingEmptySubsequences: true)
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? "text/plain"
    }

    private static func mediaTypeParameters(from contentType: String) -> [String: String] {
        var segments: [String] = []
        var current = ""
        var quoted = false
        var escaped = false
        for character in contentType {
            if escaped {
                current.append(character)
                escaped = false
            } else if character == "\\", quoted {
                escaped = true
            } else if character == "\"" {
                quoted.toggle()
                current.append(character)
            } else if character == ";", !quoted {
                segments.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }
        segments.append(current)

        var parameters: [String: String] = [:]
        for segment in segments.dropFirst() {
            guard let equals = segment.firstIndex(of: "=") else { continue }
            let key = segment[..<equals].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            var value = segment[segment.index(after: equals)...].trimmingCharacters(in: .whitespacesAndNewlines)
            if value.count >= 2, value.first == "\"", value.last == "\"" {
                value.removeFirst()
                value.removeLast()
            }
            parameters[key] = value
        }
        return parameters
    }

    private static func decodeQuotedPrintable(_ data: Data) -> Data {
        let bytes = [UInt8](data)
        var decoded = Data()
        var index = 0
        while index < bytes.count {
            guard bytes[index] == 0x3D else {
                decoded.append(bytes[index])
                index += 1
                continue
            }
            if index + 2 < bytes.count, bytes[index + 1] == 0x0D, bytes[index + 2] == 0x0A {
                index += 3
                continue
            }
            if index + 1 < bytes.count, bytes[index + 1] == 0x0A {
                index += 2
                continue
            }
            if index + 2 < bytes.count,
               let high = hexadecimalValue(bytes[index + 1]),
               let low = hexadecimalValue(bytes[index + 2]) {
                decoded.append((high << 4) | low)
                index += 3
                continue
            }
            decoded.append(bytes[index])
            index += 1
        }
        return decoded
    }

    private static func hexadecimalValue(_ byte: UInt8) -> UInt8? {
        switch byte {
        case 0x30...0x39: return byte - 0x30
        case 0x41...0x46: return byte - 0x41 + 10
        case 0x61...0x66: return byte - 0x61 + 10
        default: return nil
        }
    }

    private static func stringEncoding(forIANACharset charset: String) -> String.Encoding? {
        let cfEncoding = CFStringConvertIANACharSetNameToEncoding(charset as CFString)
        guard cfEncoding != kCFStringEncodingInvalidId else { return nil }
        let nsEncoding = CFStringConvertEncodingToNSStringEncoding(cfEncoding)
        return String.Encoding(rawValue: nsEncoding)
    }

    private static func lineEnding(for part: Part, in data: Data) -> String {
        if firstOccurrence(of: [0x0D, 0x0A], in: part.headerRange, data: data) != nil {
            return "\r\n"
        }
        return "\n"
    }

    private static func wrappedBase64(_ body: Data, eol: String) -> Data {
        let encoded = body.base64EncodedString()
        var lines: [String] = []
        var index = encoded.startIndex
        while index < encoded.endIndex {
            let end = encoded.index(index, offsetBy: 76, limitedBy: encoded.endIndex) ?? encoded.endIndex
            lines.append(String(encoded[index..<end]))
            index = end
        }
        return Data((lines.joined(separator: eol) + eol).utf8)
    }

    private static func rewritingTopLevelHeaders(
        _ headerData: Data.SubSequence,
        contentType: String,
        eol: String
    ) -> Data {
        struct HeaderLine {
            let contentRange: Range<Int>
            let fullRange: Range<Int>
        }

        func fieldName(in range: Range<Int>) -> String? {
            var colon = range.lowerBound
            while colon < range.upperBound, headerData[colon] != 0x3A {
                colon += 1
            }
            guard colon < range.upperBound else { return nil }
            var lower = range.lowerBound
            var upper = colon
            while lower < upper, headerData[lower] == 0x20 || headerData[lower] == 0x09 {
                lower += 1
            }
            while upper > lower, headerData[upper - 1] == 0x20 || headerData[upper - 1] == 0x09 {
                upper -= 1
            }
            return String(data: headerData[lower..<upper], encoding: .ascii)?.lowercased()
        }

        var lines: [HeaderLine] = []
        var lineStart = headerData.startIndex
        var cursor = lineStart
        while cursor < headerData.endIndex {
            if headerData[cursor] == 0x0A {
                var contentEnd = cursor
                if contentEnd > lineStart, headerData[contentEnd - 1] == 0x0D {
                    contentEnd -= 1
                }
                lines.append(
                    HeaderLine(
                        contentRange: lineStart..<contentEnd,
                        fullRange: lineStart..<(cursor + 1)
                    )
                )
                lineStart = cursor + 1
            }
            cursor += 1
        }
        if lineStart < headerData.endIndex {
            lines.append(
                HeaderLine(
                    contentRange: lineStart..<headerData.endIndex,
                    fullRange: lineStart..<headerData.endIndex
                )
            )
        }

        var result = Data()
        var foundContentType = false
        var foundCTE = false
        var index = 0
        while index < lines.count {
            let first = lines[index]
            var last = first
            index += 1
            while index < lines.count {
                let next = lines[index]
                guard let firstByte = headerData[next.contentRange].first,
                      firstByte == 0x20 || firstByte == 0x09 else {
                    break
                }
                last = next
                index += 1
            }

            let name = fieldName(in: first.contentRange)
            let hadTrailingEOL = last.fullRange.upperBound > last.contentRange.upperBound
            if name == "content-type" {
                result.append(Data("Content-Type: \(contentType); charset=utf-8".utf8))
                if hadTrailingEOL { result.append(Data(eol.utf8)) }
                foundContentType = true
            } else if name == "content-transfer-encoding" {
                result.append(Data("Content-Transfer-Encoding: base64".utf8))
                if hadTrailingEOL { result.append(Data(eol.utf8)) }
                foundCTE = true
            } else {
                result.append(headerData[first.fullRange.lowerBound..<last.fullRange.upperBound])
            }
        }

        if !foundContentType {
            if !result.isEmpty { result.append(Data(eol.utf8)) }
            result.append(Data("Content-Type: \(contentType); charset=utf-8".utf8))
        }
        if !foundCTE {
            if !result.isEmpty { result.append(Data(eol.utf8)) }
            result.append(Data("Content-Transfer-Encoding: base64".utf8))
        }
        return result
    }
}
