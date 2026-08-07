import Foundation

/// Per-message translation state. All mutations are generation-guarded so an
/// older task cannot overwrite a newer continuation or a stopped message.
final class TranslationStore: @unchecked Sendable {
    enum DisplayMode: Equatable {
        case bilingual
        case original
    }

    struct Presentation: Equatable {
        let token: UInt
        let action: TranslationActionContext.Action
        let displayMode: DisplayMode
    }

    struct Stash {
        let contentType: String
        let original: Data
        let sourceHTML: String
        let segments: [HTMLSegments.Segment]
    }

    enum State {
        case idle
        case translating(
            completedSegments: Int,
            totalSegments: Int,
            latestRewritten: Data?,
            cancellationPresented: Bool,
            generation: UInt
        )
        case stopped(
            completedSegments: Int,
            totalSegments: Int,
            latestRewritten: Data?,
            generation: UInt
        )
        case done(rewritten: Data, generation: UInt)
        case failed(String, latestRewritten: Data?, generation: UInt)
    }

    enum Action: Equatable {
        case start
        case ignoreRedelivery
        case stop
        case continueTranslation
        case retranslate
        case retry
    }

    static let shared = TranslationStore()

    private struct Entry {
        var state: State
        var stash: Stash?
        var translations: [Int: String]
        var displayMode: DisplayMode = .bilingual
        var presentation: Presentation?
    }

    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    private var insertionOrder: [String] = []
    private var nextGeneration: UInt = 1
    private var nextPresentationToken: UInt = 1
    private let capacity = 16

    private init() {}

    func state(for key: String) -> State {
        lock.withLock { entries[key]?.state ?? .idle }
    }

    func action(for key: String) -> Action {
        lock.withLock {
            guard let entry = entries[key] else { return .start }
            switch entry.state {
            case .idle:
                return .start
            case .translating(_, _, _, let cancellationPresented, _):
                return cancellationPresented ? .stop : .ignoreRedelivery
            case .stopped:
                return .continueTranslation
            case .done:
                return .retranslate
            case .failed:
                return entry.translations.isEmpty ? .retry : .continueTranslation
            }
        }
    }

    func displayMode(for key: String) -> DisplayMode {
        lock.withLock { entries[key]?.displayMode ?? .bilingual }
    }

    /// Mints the context token for the banner currently being rendered.
    func present(key: String, action: TranslationActionContext.Action) -> Presentation? {
        lock.withLock {
            guard var entry = entries[key] else { return nil }
            if let presentation = entry.presentation,
               presentation.action == action,
               presentation.displayMode == entry.displayMode {
                return presentation
            }
            let presentation = Presentation(
                token: allocatePresentationToken(),
                action: action,
                displayMode: entry.displayMode
            )
            entry.presentation = presentation
            entries[key] = entry
            return presentation
        }
    }

    /// Consumes a context only when it exactly matches the latest rendered banner.
    func resolveAction(
        key: String,
        token: UInt,
        action: TranslationActionContext.Action
    ) -> TranslationActionContext.Action? {
        lock.withLock {
            guard var entry = entries[key],
                  let presentation = entry.presentation,
                  presentation.token == token,
                  presentation.action == action else {
                return nil
            }
            entry.presentation = nil
            entries[key] = entry
            return action
        }
    }

    /// Applies a display action already accepted by `resolveAction`.
    func toggleOriginalView(key: String, action: TranslationActionContext.Action) -> Bool {
        lock.withLock {
            guard var entry = entries[key],
                  case .done = entry.state else {
                return false
            }
            switch action {
            case .showOriginal:
                entry.displayMode = .original
            case .showBilingual:
                entry.displayMode = .bilingual
            default:
                return false
            }
            entries[key] = entry
            return true
        }
    }

    func stash(key: String, stash: Stash) {
        lock.withLock {
            if var entry = entries[key] {
                entry.stash = stash
                entries[key] = entry
            } else {
                insert(Entry(state: .idle, stash: stash, translations: [:]), for: key)
            }
        }
    }

    func stashed(key: String) -> Stash? {
        lock.withLock { entries[key]?.stash }
    }

    func translations(key: String) -> [Int: String] {
        lock.withLock { entries[key]?.translations ?? [:] }
    }

    func missingIndexes(key: String) -> [Int] {
        lock.withLock {
            guard let entry = entries[key], let stash = entry.stash else { return [] }
            return stash.segments.indices.filter { entry.translations[$0] == nil }
        }
    }

    /// Starts fresh work or a continuation. `preserveExisting` is valid only
    /// after a stopped/failed task and keeps its accumulated translations.
    func markTranslating(
        key: String,
        totalSegments: Int,
        prefilled: [Int: String],
        preserveExisting: Bool = false
    ) -> UInt? {
        lock.withLock {
            let generation = allocateGeneration()
            if var entry = entries[key] {
                let existingRewritten = rewritten(in: entry.state)
                switch entry.state {
                case .idle:
                    entry.translations = prefilled
                case .stopped, .failed:
                    if preserveExisting {
                        for (index, translation) in prefilled {
                            entry.translations[index] = translation
                        }
                    } else {
                        entry.translations = prefilled
                    }
                case .done:
                    guard !preserveExisting else { return nil }
                    entry.translations = prefilled
                case .translating:
                    return nil
                }
                entry.state = .translating(
                    completedSegments: entry.translations.count,
                    totalSegments: totalSegments,
                    latestRewritten: preserveExisting ? existingRewritten : nil,
                    cancellationPresented: false,
                    generation: generation
                )
                entry.displayMode = .bilingual
                entry.presentation = nil
                entries[key] = entry
            } else {
                insert(
                    Entry(
                        state: .translating(
                            completedSegments: prefilled.count,
                            totalSegments: totalSegments,
                            latestRewritten: nil,
                            cancellationPresented: false,
                            generation: generation
                    ),
                    stash: nil,
                    translations: prefilled,
                    displayMode: .bilingual,
                    presentation: nil
                ),
                    for: key
                )
            }
            return generation
        }
    }

    func markCancellationPresented(key: String) {
        lock.withLock {
            guard var entry = entries[key],
                  case .translating(let completed, let total, let latest, false, let generation) = entry.state else {
                return
            }
            entry.state = .translating(
                completedSegments: completed,
                totalSegments: total,
                latestRewritten: latest,
                cancellationPresented: true,
                generation: generation
            )
            entries[key] = entry
        }
    }

    func updateProgress(
        key: String,
        generation: UInt,
        translations batch: [Int: String],
        rewritten: Data?
    ) -> Bool {
        lock.withLock {
            guard var entry = entries[key],
                  case .translating(_, let total, _, let cancellationPresented, let currentGeneration) = entry.state,
                  currentGeneration == generation else {
                return false
            }
            for (index, translation) in batch {
                entry.translations[index] = translation
            }
            entry.state = .translating(
                completedSegments: entry.translations.count,
                totalSegments: total,
                latestRewritten: rewritten,
                cancellationPresented: cancellationPresented,
                generation: currentGeneration
            )
            entries[key] = entry
            return true
        }
    }

    func stop(key: String, generation: UInt) -> Bool {
        lock.withLock {
            guard var entry = entries[key],
                  case .translating(_, let total, let latest, _, let currentGeneration) = entry.state,
                  currentGeneration == generation else {
                return false
            }
            entry.state = .stopped(
                completedSegments: entry.translations.count,
                totalSegments: total,
                latestRewritten: latest,
                generation: currentGeneration
            )
            entries[key] = entry
            return true
        }
    }

    func finish(key: String, generation: UInt, rewritten: Data) -> Bool {
        lock.withLock {
            guard var entry = entries[key],
                  case .translating(_, _, _, _, let currentGeneration) = entry.state,
                  currentGeneration == generation else {
                return false
            }
            entry.state = .done(rewritten: rewritten, generation: currentGeneration)
            entry.displayMode = .bilingual
            entry.presentation = nil
            entries[key] = entry
            return true
        }
    }

    func finish(key: String, rewritten: Data) {
        lock.withLock {
            if var entry = entries[key] {
                entry.state = .done(rewritten: rewritten, generation: 0)
                entry.displayMode = .bilingual
                entry.presentation = nil
                entries[key] = entry
            } else {
                insert(
                    Entry(
                        state: .done(rewritten: rewritten, generation: 0),
                        stash: nil,
                        translations: [:],
                        displayMode: .bilingual,
                        presentation: nil
                    ),
                    for: key
                )
            }
        }
    }

    func fail(key: String, generation: UInt, message: String) -> Bool {
        lock.withLock {
            guard var entry = entries[key],
                  case .translating(_, _, _, _, let currentGeneration) = entry.state,
                  currentGeneration == generation else {
                return false
            }
            entry.state = .failed(message, latestRewritten: rewritten(in: entry.state), generation: generation)
            entries[key] = entry
            return true
        }
    }

    func fail(key: String, message: String) {
        lock.withLock {
            if var entry = entries[key] {
                entry.state = .failed(message, latestRewritten: rewritten(in: entry.state), generation: 0)
                entries[key] = entry
            } else {
                insert(Entry(state: .failed(message, latestRewritten: nil, generation: 0), stash: nil, translations: [:]), for: key)
            }
        }
    }

    func reset(key: String) {
        lock.withLock {
            guard var entry = entries[key] else { return }
            switch entry.state {
            case .done, .failed, .stopped:
                entry.state = .idle
                entry.translations = [:]
                entry.displayMode = .bilingual
                entry.presentation = nil
                entries[key] = entry
            case .idle, .translating:
                return
            }
        }
    }

    private func allocateGeneration() -> UInt {
        defer { nextGeneration &+= 1 }
        return nextGeneration
    }

    private func allocatePresentationToken() -> UInt {
        defer { nextPresentationToken &+= 1 }
        return nextPresentationToken
    }

    private func rewritten(in state: State) -> Data? {
        switch state {
        case .translating(_, _, let latest, _, _), .stopped(_, _, let latest, _), .failed(_, let latest, _):
            return latest
        case .done(let rewritten, _):
            return rewritten
        case .idle:
            return nil
        }
    }

    private func insert(_ entry: Entry, for key: String) {
        if insertionOrder.count >= capacity, let oldest = insertionOrder.first {
            insertionOrder.removeFirst()
            entries.removeValue(forKey: oldest)
        }
        insertionOrder.append(key)
        entries[key] = entry
    }
}

extension NSLock {
    func withLock<T>(_ body: () throws -> T) rethrows -> T {
        lock()
        defer { unlock() }
        return try body()
    }
}
