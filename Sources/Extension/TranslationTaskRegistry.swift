import Foundation

/// Owns one cancellable top-level translation task for each visible message.
final class TranslationTaskRegistry: @unchecked Sendable {
    struct Handle: Equatable {
        let key: String
        let generation: UInt
    }

    private struct Entry {
        let handle: Handle
        var task: Task<Void, Never>?
        var cancelled: Bool
    }

    private let lock = NSLock()
    private var entries: [String: Entry] = [:]
    private var nextGeneration: UInt = 1

    func register(key: String, task: Task<Void, Never>) -> Handle? {
        let generation = lock.withLock { nextGeneration }
        guard let handle = reserve(key: key, generation: generation) else {
            task.cancel()
            return nil
        }
        guard attach(task, to: handle) else { return nil }
        return handle
    }

    func register(key: String, generation: UInt, task: Task<Void, Never>) -> Handle? {
        guard let handle = reserve(key: key, generation: generation) else {
            task.cancel()
            return nil
        }
        guard attach(task, to: handle) else { return nil }
        return handle
    }

    func reserve(key: String, generation: UInt) -> Handle? {
        lock.withLock {
            guard entries[key] == nil else { return nil }
            let handle = Handle(key: key, generation: generation)
            nextGeneration = max(nextGeneration &+ 1, generation &+ 1)
            entries[key] = Entry(handle: handle, task: nil, cancelled: false)
            return handle
        }
    }

    func attach(_ task: Task<Void, Never>, to handle: Handle) -> Bool {
        let accepted = lock.withLock { () -> Bool in
            guard var entry = entries[handle.key],
                  entry.handle == handle,
                  !entry.cancelled,
                  entry.task == nil else {
                return false
            }
            entry.task = task
            entries[handle.key] = entry
            return true
        }
        if !accepted {
            task.cancel()
        }
        return accepted
    }

    func cancelReservation(_ handle: Handle) -> Bool {
        let result = lock.withLock { () -> (cancelled: Bool, task: Task<Void, Never>?) in
            guard var entry = entries[handle.key],
                  entry.handle == handle,
                  !entry.cancelled else {
                return (false, nil)
            }
            entry.cancelled = true
            entries[handle.key] = entry
            return (true, entry.task)
        }
        result.task?.cancel()
        return result.cancelled
    }

    func cancel(_ handle: Handle) -> Bool {
        cancelReservation(handle)
    }

    func handle(for key: String) -> Handle? {
        lock.withLock { entries[key]?.handle }
    }

    func remove(_ handle: Handle) {
        lock.withLock {
            guard entries[handle.key]?.handle == handle else { return }
            entries.removeValue(forKey: handle.key)
        }
    }

    func remove(key: String, generation: UInt) {
        remove(Handle(key: key, generation: generation))
    }
}
