import Foundation

/// 翻译管线：分段 → 分批 → 限流并发 → 渐进回调。
struct TranslationPipeline: Sendable {
    let engine: TranslationEngine
    let target: TargetLanguage

    /// 按字符上限把分段切成批次（保持顺序）。
    static func planBatches(
        _ inputs: [TranslationInput],
        characterLimit: Int
    ) -> [[TranslationInput]] {
        var batches: [[TranslationInput]] = []
        var current: [TranslationInput] = []
        var currentLength = 0
        for input in inputs {
            let length = max(input.html.count, input.plainText.count) + 8
            if !current.isEmpty, currentLength + length > characterLimit {
                batches.append(current)
                current = []
                currentLength = 0
            }
            current.append(input)
            currentLength += length
        }
        if !current.isEmpty {
            batches.append(current)
        }
        return batches
    }

    /// 并发执行全部批次。
    /// - onBatchResult: 每批完成即回调（含该批全部单段结果），调用方据此渐进刷新 UI。
    /// - 单批失败不拖垮整体：返回部分结果 + 第一个错误。
    func translate(
        inputs: [TranslationInput],
        onSegment: @escaping @Sendable (Int, String) -> Void,
        onBatchResult: @escaping @Sendable ([Int: String], _ doneBatches: Int, _ totalBatches: Int) -> Void
    ) async throws -> [Int: String] {
        let batches = Self.planBatches(inputs, characterLimit: engine.batchCharacterLimit)
        guard !batches.isEmpty else { return [:] }

        let total = batches.count
        let progress = ProgressCounter()

        return try await withThrowingTaskGroup(
            of: (Int, Result<[Int: String], Error>).self
        ) { group in
            var nextBatchIndex = 0
            var running = 0
            var firstError: Error?
            var merged: [Int: String] = [:]

            func enqueue(_ batchIndex: Int) {
                let batch = batches[batchIndex]
                group.addTask { [engine, target] in
                    do {
                        try Task.checkCancellation()
                        let results = try await engine.translate(
                            batch: batch,
                            target: target,
                            onSegment: { index, translation in
                                guard !Task.isCancelled else { return }
                                onSegment(index, translation)
                            }
                        )
                        try Task.checkCancellation()
                        return (batchIndex, .success(results))
                    } catch is CancellationError {
                        throw CancellationError()
                    } catch {
                        return (batchIndex, .failure(error))
                    }
                }
                running += 1
            }

            while nextBatchIndex < total, running < engine.maxConcurrentBatches {
                try Task.checkCancellation()
                enqueue(nextBatchIndex)
                nextBatchIndex += 1
            }

            do {
                while let (_, result) = try await group.next() {
                    try Task.checkCancellation()
                    running -= 1
                    switch result {
                    case .success(let partial):
                        merged.merge(partial) { _, new in new }
                    case .failure(let error):
                        if firstError == nil { firstError = error }
                    }
                    let done = progress.increment()
                    if case .success(let partial) = result {
                        try Task.checkCancellation()
                        onBatchResult(partial, done, total)
                    }
                    if nextBatchIndex < total {
                        try Task.checkCancellation()
                        enqueue(nextBatchIndex)
                        nextBatchIndex += 1
                    }
                }
            } catch is CancellationError {
                group.cancelAll()
                throw CancellationError()
            }

            try Task.checkCancellation()
            if merged.isEmpty, let firstError {
                throw firstError
            }
            return merged
        }
    }
}

private final class ProgressCounter: @unchecked Sendable {
    private let lock = NSLock()
    private var value = 0

    func increment() -> Int {
        lock.lock()
        defer { lock.unlock() }
        value += 1
        return value
    }
}
