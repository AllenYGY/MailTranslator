import Foundation
import NaturalLanguage
import Translation

/// Apple 系统翻译：设备端、免费。
/// 注意：程序化构造 TranslationSession（installedSource:target:）需要 macOS 26+；
/// 更早系统只能通过 SwiftUI translationTask 获取 session，MailKit 扩展里用不了。
struct AppleTranslationEngine: TranslationEngine {
    var kind: ProviderKind { .apple }
    var batchCharacterLimit: Int { 6000 }
    var maxConcurrentBatches: Int { 2 }

    init() {}

    func translate(
        batch: [TranslationInput],
        target: TargetLanguage,
        onSegment: @Sendable (Int, String) -> Void
    ) async throws -> [Int: String] {
        try Task.checkCancellation()
        guard #available(macOS 26.0, *) else {
            throw EngineError.unsupported("Apple 系统翻译需要 macOS 26 或更高版本")
        }
        return try await runBatch(batch: batch, target: target, onSegment: onSegment)
    }

    @available(macOS 26.0, *)
    private func runBatch(
        batch: [TranslationInput],
        target: TargetLanguage,
        onSegment: @Sendable (Int, String) -> Void
    ) async throws -> [Int: String] {
        let combined = batch.map(\.plainText).joined(separator: "\n")
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(combined)
        let sourceCode = recognizer.dominantLanguage?.rawValue ?? "en"
        let source = Locale.Language(
            identifier: sourceCode == "und" ? "en" : sourceCode
        )

        let session = TranslationSession(installedSource: source, target: target.localeLanguage)
        do {
            try await session.prepareTranslation()
            try Task.checkCancellation()
        } catch {
            if error is CancellationError { throw error }
            throw EngineError.unsupported("系统翻译语言包未就绪（\(sourceCode) → \(target.volcCode)），请在系统设置中下载")
        }

        var results: [Int: String] = [:]
        for entry in batch {
            try Task.checkCancellation()
            do {
                let response = try await session.translate(entry.plainText)
                try Task.checkCancellation()
                let translation = response.targetText.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !translation.isEmpty else { continue }
                let insertion = InsertionHTML.fromPlainText(translation)
                results[entry.index] = insertion
                onSegment(entry.index, insertion)
            } catch is CancellationError {
                throw CancellationError()
            } catch {
                continue // 单段失败不中断整批
            }
        }
        if results.isEmpty {
            throw EngineError.unsupported("Apple 系统翻译没有产出任何译文")
        }
        return results
    }
}
