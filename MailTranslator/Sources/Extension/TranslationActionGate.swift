import Foundation

final class TranslationActionGate: @unchecked Sendable {
    private let cooldown: TimeInterval
    private let lock = NSLock()
    private var lastStartByKey: [String: Date] = [:]

    init(cooldown: TimeInterval) {
        self.cooldown = cooldown
    }

    func begin(key: String, now: Date = Date()) -> Bool {
        lock.lock()
        defer { lock.unlock() }

        if let lastStart = lastStartByKey[key],
           now.timeIntervalSince(lastStart) < cooldown {
            return false
        }
        lastStartByKey[key] = now
        return true
    }
}
