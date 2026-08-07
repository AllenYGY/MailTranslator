import Foundation

enum HTMLSegments {
    struct Segment {
        let range: Range<String.Index>
        let html: String
    }

    private static let inlineTags: Set<String> = [
        "a", "abbr", "b", "bdi", "bdo", "big", "cite", "code", "data", "del",
        "dfn", "em", "font", "i", "img", "ins", "kbd", "mark", "q", "s", "samp",
        "small", "span", "strike", "strong", "sub", "sup", "time", "tt", "u", "var",
        "wbr", "br",
    ]

    static func extract(from html: String) -> [Segment] {
        var segments: [Segment] = []
        var index = html.startIndex
        var segmentStart: String.Index?
        var lastVisibleEnd: String.Index?
        var hasLetter = false

        func finishSegment() {
            if hasLetter, let start = segmentStart, let end = lastVisibleEnd, start < end {
                let range = start..<end
                segments.append(Segment(range: range, html: String(html[range])))
            }
            segmentStart = nil
            lastVisibleEnd = nil
            hasLetter = false
        }

        while index < html.endIndex {
            if html[index...].hasPrefix("<!--") {
                guard let close = html[index...].range(of: "-->") else {
                    break
                }
                index = close.upperBound
                continue
            }

            if html[index] == "<" {
                guard let close = html[index...].firstIndex(of: ">") else {
                    break
                }
                let rawTag = String(html[html.index(after: index)..<close])
                let tag = HTMLText.tagName(from: rawTag)
                let closing = rawTag.trimmingCharacters(in: .whitespacesAndNewlines).hasPrefix("/")

                if !closing, ["script", "style", "title"].contains(tag) {
                    guard let end = HTMLText.endOfElement(named: tag, after: close, in: html) else {
                        break
                    }
                    index = end
                    continue
                }

                if inlineTags.contains(tag) {
                    if segmentStart == nil, !closing {
                        segmentStart = index
                    }
                    if segmentStart != nil {
                        lastVisibleEnd = html.index(after: close)
                    }
                } else {
                    finishSegment()
                }
                index = html.index(after: close)
                continue
            }

            if html[index] == "&", let entityEnd = endOfEntity(after: index, in: html) {
                if segmentStart == nil {
                    segmentStart = index
                }
                lastVisibleEnd = html.index(after: entityEnd)
                index = html.index(after: entityEnd)
                continue
            }

            let character = html[index]
            if !character.isWhitespace {
                if segmentStart == nil {
                    segmentStart = index
                }
                lastVisibleEnd = html.index(after: index)
                if character.isLetter {
                    hasLetter = true
                }
            }
            index = html.index(after: index)
        }

        finishSegment()
        return segments
    }

    static func insertingTranslations(
        _ translations: [String?],
        into html: String,
        segments: [Segment]
    ) -> String {
        precondition(translations.count == segments.count)
        let insertionOffsets = segments.map {
            html.distance(from: html.startIndex, to: $0.range.upperBound)
        }
        var result = html

        for index in segments.indices.reversed() {
            guard let translation = translations[index] else {
                continue
            }
            let insertionIndex = result.index(result.startIndex, offsetBy: insertionOffsets[index])
            result.insert(
                contentsOf: "<br><span style=\"color:#FF0000\">\(translation)</span>",
                at: insertionIndex
            )
        }
        return result
    }

    static func htmlFromPlainText(_ text: String) -> String {
        let escaped = text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&#39;")
        let normalized = escaped
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        return normalized
            .components(separatedBy: "\n\n")
            .filter { !$0.isEmpty }
            .map { "<p>\($0.replacingOccurrences(of: "\n", with: "<br>"))</p>" }
            .joined()
    }

    static func payload(for entries: [(index: Int, html: String)]) -> String {
        var result = ""
        result.reserveCapacity(entries.reduce(0) { $0 + $1.html.count + 8 })
        for entry in entries {
            result += "@@\(entry.index)@@\n\(entry.html)\n"
        }
        return result
    }

    static func parseResponse(_ response: String) -> [Int: String] {
        let normalized = response
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let lines = normalized.components(separatedBy: "\n")
        var translations: [Int: String] = [:]
        var currentIndex: Int?
        var currentLines: [String] = []

        func finishTranslation() {
            guard let index = currentIndex else {
                return
            }
            let translation = currentLines
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !translation.isEmpty {
                translations[index] = translation
            }
        }

        for line in lines {
            if let marker = markerIndex(in: line) {
                finishTranslation()
                currentIndex = marker
                currentLines.removeAll(keepingCapacity: true)
            } else if currentIndex != nil {
                currentLines.append(line)
            }
        }
        finishTranslation()
        return translations
    }

    private static func endOfEntity(after start: String.Index, in html: String) -> String.Index? {
        var cursor = html.index(after: start)
        var count = 0
        while cursor < html.endIndex, count < 32 {
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

    private static func markerIndex(in line: String) -> Int? {
        let marker = line.trimmingCharacters(in: CharacterSet(charactersIn: " \t"))
        guard marker.hasPrefix("@@"), marker.hasSuffix("@@"), marker.count > 4 else {
            return nil
        }
        let digits = marker.dropFirst(2).dropLast(2)
        guard digits.allSatisfy({ $0.isNumber }) else {
            return nil
        }
        return Int(digits)
    }
}
