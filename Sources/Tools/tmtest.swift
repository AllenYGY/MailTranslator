import Foundation

@main
struct TMTest {
    static func main() async throws {
        let arguments = CommandLine.arguments
        guard arguments.count == 3 else {
            throw usageError()
        }

        let data = try Data(contentsOf: URL(fileURLWithPath: arguments[2]))
        let message = MIMEMessage(data: data)
        guard let part = message.displayPart() else {
            throw toolError(2, "没有可展示的 text/plain 或 text/html part")
        }
        guard let decoded = MIMEMessage.decodeBody(
            data[part.bodyRange],
            cte: part.cte,
            charset: part.charset
        ) else {
            throw toolError(3, "展示 part 解码失败")
        }
        let sourceHTML = part.contentType == "text/html"
            ? decoded
            : HTMLSegments.htmlFromPlainText(decoded)

        switch arguments[1] {
        case "parse":
            print("content-type: \(part.contentType)")
            print("characters: \(decoded.count)")
            print(String(decoded.prefix(300)))

        case "segments":
            for (index, segment) in HTMLSegments.extract(from: sourceHTML).enumerated() {
                print("#\(index): \(segment.html)")
            }

        case "translate", "rewrite":
            let config = Settings.current
            let engine = try EngineFactory.makeEngine(config: config)
            let segments = HTMLSegments.extract(from: sourceHTML)
            guard !segments.isEmpty else {
                throw toolError(4, "没有可翻译的内容")
            }
            let inputs = segments.enumerated().map { index, segment in
                TranslationInput(
                    index: index,
                    html: segment.html,
                    plainText: HTMLText.stripToPlainText(segment.html)
                )
            }
            fputs(
                "engine: \(config.providerKind.displayName), target: \(config.target.displayName), "
                + "segments: \(inputs.count)\n",
                stderr
            )
            let started = Date()
            let pipeline = TranslationPipeline(engine: engine, target: config.target)
            let translations = try await pipeline.translate(
                inputs: inputs,
                onSegment: { index, _ in
                    fputs("segment #\(index) done (+\(String(format: "%.1f", Date().timeIntervalSince(started)))s)\n", stderr)
                },
                onBatchResult: { _, done, total in
                    fputs("batch \(done)/\(total) done\n", stderr)
                }
            )
            fputs(
                "finished \(translations.count)/\(inputs.count) segments in "
                + String(format: "%.1f", Date().timeIntervalSince(started)) + "s\n",
                stderr
            )

            if arguments[1] == "translate" {
                for index in inputs.map(\.index) {
                    if let translation = translations[index] {
                        print("#\(index): \(translation)")
                    }
                }
            } else {
                let ordered = segments.indices.map { translations[$0] }
                let bilingual = HTMLSegments.insertingTranslations(
                    ordered,
                    into: sourceHTML,
                    segments: segments
                )
                let rewritten = MIMEMessage.replacing(
                    part: part,
                    with: Data(bilingual.utf8),
                    contentType: "text/html",
                    in: data
                )
                try FileHandle.standardOutput.write(contentsOf: rewritten)
            }

        default:
            throw usageError()
        }
    }

    private static func usageError() -> NSError {
        toolError(1, "用法: tmtest parse|segments|translate|rewrite <email.eml>（引擎用 MT_PROVIDER/MT_API_BASE 等环境变量配置）")
    }

    private static func toolError(_ code: Int, _ message: String) -> NSError {
        NSError(domain: "tmtest", code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
