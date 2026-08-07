import Foundation

/// Serializes Mail reloads and collapses rapid progress notifications.
final class TranslationRefreshCoordinator: @unchecked Sendable {
    enum Request: Equatable {
        case initial
        case progress
        case terminal
    }

    private enum Command {
        case none
        case execute(Request)
        case schedule(TimeInterval)
    }

    private let minimumProgressInterval: TimeInterval
    private let now: () -> Date
    private let execute: (Request, @escaping () -> Void) -> Void
    private let schedule: (TimeInterval, @escaping () -> Void) -> Void
    private let lock = NSLock()

    private var isReloading = false
    private var pending: Request?
    private var activeReloadCompletions: [() -> Void] = []
    private var pendingReloadCompletions: [() -> Void] = []
    private var deferredInitialCompletions: [() -> Void] = []
    private var timerScheduled = false
    private var lastReloadStart: Date?

    init(
        minimumProgressInterval: TimeInterval = 1,
        now: @escaping () -> Date = Date.init,
        execute: @escaping (Request, @escaping () -> Void) -> Void,
        schedule: @escaping (TimeInterval, @escaping () -> Void) -> Void
    ) {
        self.minimumProgressInterval = minimumProgressInterval
        self.now = now
        self.execute = execute
        self.schedule = schedule
    }

    func request(_ request: Request) {
        let command = lock.withLock {
            let pendingBeforeRequest = pending
            let command = requestCommand(request, at: now())
            deferInitialCompletionsIfDisplaced(
                pendingBeforeRequest: pendingBeforeRequest,
                request: request,
                command: command
            )
            promotePendingCompletions(for: command)
            return command
        }
        run(command)
    }

    /// Runs after the next serialized Mail reload completes, even when this
    /// request is coalesced behind a higher-priority reload.
    func request(_ request: Request, afterReload completion: @escaping () -> Void) {
        let command = lock.withLock {
            if request == .initial, isReloading, pending == .terminal {
                deferredInitialCompletions.append(completion)
                return Command.none
            }
            let pendingBeforeRequest = pending
            let command = requestCommand(request, at: now())
            deferInitialCompletionsIfDisplaced(
                pendingBeforeRequest: pendingBeforeRequest,
                request: request,
                command: command
            )
            switch command {
            case .execute:
                promotePendingCompletions(for: command)
                activeReloadCompletions.append(completion)
            case .none, .schedule:
                pendingReloadCompletions.append(completion)
            }
            return command
        }
        run(command)
    }

    private func requestCommand(_ request: Request, at date: Date) -> Command {
        if isReloading {
            pending = preferred(request, over: pending)
            return .none
        }

        if request != .progress {
            pending = nil
            return begin(request, at: date)
        }

        return begin(.progress, at: date)
    }

    private func begin(_ request: Request, at date: Date) -> Command {
        if request == .progress,
           let lastReloadStart {
            let elapsed = date.timeIntervalSince(lastReloadStart)
            if elapsed < minimumProgressInterval {
                pending = preferred(.progress, over: pending)
                guard !timerScheduled else { return .none }
                timerScheduled = true
                return .schedule(minimumProgressInterval - elapsed)
            }
        }

        isReloading = true
        lastReloadStart = date
        return .execute(request)
    }

    private func run(_ command: Command) {
        switch command {
        case .none:
            return
        case .execute(let request):
            execute(request) { [weak self] in self?.reloadFinished() }
        case .schedule(let delay):
            schedule(delay) { [weak self] in self?.runScheduledRequest() }
        }
    }

    private func reloadFinished() {
        let result = lock.withLock { () -> (completions: [() -> Void], command: Command) in
            isReloading = false
            let completions = activeReloadCompletions
            activeReloadCompletions = []
            let request: Request
            if let pending {
                self.pending = nil
                request = pending
            } else if !deferredInitialCompletions.isEmpty {
                request = .initial
            } else {
                return (completions, .none)
            }
            let command = begin(request, at: now())
            promotePendingCompletions(for: command)
            promoteDeferredInitialCompletions(for: command)
            return (completions, command)
        }
        result.completions.forEach { $0() }
        run(result.command)
    }

    private func runScheduledRequest() {
        let command = lock.withLock { () -> Command in
            timerScheduled = false
            guard !isReloading, let request = pending else { return .none }
            pending = nil
            let command = begin(request, at: now())
            promotePendingCompletions(for: command)
            promoteDeferredInitialCompletions(for: command)
            return command
        }
        run(command)
    }

    private func promotePendingCompletions(for command: Command) {
        guard case .execute = command else { return }
        activeReloadCompletions.append(contentsOf: pendingReloadCompletions)
        pendingReloadCompletions = []
    }

    private func deferInitialCompletionsIfDisplaced(
        pendingBeforeRequest: Request?,
        request: Request,
        command: Command
    ) {
        guard pendingBeforeRequest == .initial,
              request == .terminal else {
            return
        }
        let terminalWillRun: Bool
        switch command {
        case .execute(.terminal):
            terminalWillRun = true
        case .none:
            terminalWillRun = pending == .terminal
        case .execute(.initial), .execute(.progress), .schedule:
            terminalWillRun = false
        }
        guard terminalWillRun else { return }
        deferredInitialCompletions.append(contentsOf: pendingReloadCompletions)
        pendingReloadCompletions = []
    }

    private func promoteDeferredInitialCompletions(for command: Command) {
        guard case .execute(.initial) = command else { return }
        activeReloadCompletions.append(contentsOf: deferredInitialCompletions)
        deferredInitialCompletions = []
    }

    private func preferred(_ candidate: Request, over current: Request?) -> Request {
        guard let current else { return candidate }
        return priority(candidate) >= priority(current) ? candidate : current
    }

    private func priority(_ request: Request) -> Int {
        switch request {
        case .progress: return 0
        case .initial: return 1
        case .terminal: return 2
        }
    }
}
