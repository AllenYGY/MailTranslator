import Foundation

enum HTMLText {
    static func stripToPlainText(_ html: String) -> String {
        var output = ""
        var index = html.startIndex

        while index < html.endIndex {
            if html[index] == "<" {
                guard let close = html[index...].firstIndex(of: ">") else {
                    output.append(contentsOf: html[index...])
                    break
                }
                let rawTag = String(html[html.index(after: index)..<close])
                let tag = tagName(from: rawTag)
                let closing = rawTag.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/")

                if !closing, tag == "script" || tag == "style" {
                    if let end = endOfElement(named: tag, after: close, in: html) {
                        index = end
                    } else {
                        break
                    }
                    continue
                }
                if tag == "br" || closing && ["p", "div", "tr"].contains(tag) {
                    output.append("\n")
                }
                index = html.index(after: close)
                continue
            }

            if html[index] == "&", let entityEnd = entityEnd(after: index, in: html) {
                let entityStart = html.index(after: index)
                let entity = String(html[entityStart..<entityEnd])
                if let decoded = decodeEntity(entity) {
                    output.append(decoded)
                    index = html.index(after: entityEnd)
                    continue
                }
            }

            output.append(html[index])
            index = html.index(after: index)
        }

        return normalizeBlankLines(output)
    }

    static func tagName(from rawTag: String) -> String {
        var tag = rawTag.trimmingCharacters(in: .whitespacesAndNewlines)
        if tag.hasPrefix("/") {
            tag.removeFirst()
            tag = tag.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return tag
            .prefix { !$0.isWhitespace && $0 != "/" }
            .lowercased()
    }

    static func endOfElement(
        named tag: String,
        after openingClose: String.Index,
        in html: String
    ) -> String.Index? {
        let searchStart = html.index(after: openingClose)
        let remainder = html[searchStart...]
        guard let closingRange = remainder.range(of: "</\(tag)", options: .caseInsensitive),
              let close = html[closingRange.lowerBound...].firstIndex(of: ">") else {
            return nil
        }
        return html.index(after: close)
    }

    private static func entityEnd(after start: String.Index, in html: String) -> String.Index? {
        var cursor = html.index(after: start)
        var count = 0
        while cursor < html.endIndex, count < 12 {
            if html[cursor] == ";" {
                return cursor
            }
            if html[cursor] == "<" || html[cursor].isWhitespace {
                return nil
            }
            cursor = html.index(after: cursor)
            count += 1
        }
        return nil
    }

    private static func decodeEntity(_ entity: String) -> String? {
        switch entity.lowercased() {
        case "amp": return "&"
        case "lt": return "<"
        case "gt": return ">"
        case "quot": return "\""
        case "#39": return "'"
        case "nbsp": return " "
        default:
            let lower = entity.lowercased()
            let value: UInt32?
            if lower.hasPrefix("#x") {
                value = UInt32(lower.dropFirst(2), radix: 16)
            } else if lower.hasPrefix("#") {
                value = UInt32(lower.dropFirst(), radix: 10)
            } else {
                value = nil
            }
            guard let value, let scalar = UnicodeScalar(value) else { return nil }
            return String(Character(scalar))
        }
    }

    private static func normalizeBlankLines(_ text: String) -> String {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.split(separator: "\n", omittingEmptySubsequences: false)
        var output: [String] = []
        var blankCount = 0
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.isEmpty {
                blankCount += 1
                if blankCount <= 2 {
                    output.append("")
                }
            } else {
                blankCount = 0
                output.append(trimmed)
            }
        }
        while output.first?.isEmpty == true { output.removeFirst() }
        while output.last?.isEmpty == true { output.removeLast() }
        return output.joined(separator: "\n")
    }
}
