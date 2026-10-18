#if APP_STORE
import Foundation
import StoreKit
import os

enum StorePurchaseAccess {
    private static let logger = Logger(subsystem: BundleID.app, category: "PurchaseAccess")
    static func restore(
        query: @escaping () async -> PurchasePolicy.State = { await state() },
        synchronize: @escaping () async throws -> Void = { try await AppStore.sync() }
    ) async throws -> PurchasePolicy.State {
        logger.notice("restore authorization check")
        if await query() == .unlocked {
            logger.notice("restore found verified permanent purchase")
            return .unlocked
        }
        // Authentication is user-paced; keep the operation busy until Apple's sheet finishes.
        logger.notice("restore requesting App Store synchronization")
        do {
            try await synchronize()
        } catch {
            let failure = error as NSError
            logger.error("restore synchronization failed domain=\(failure.domain, privacy: .public), code=\(failure.code, privacy: .public)")
            throw error
        }
        logger.notice("restore synchronization completed")
        return await query()
    }

    static func accepts(_ environment: AppStore.Environment) -> Bool {
        #if STOREKIT_LOCAL_TESTING
        return environment == .production || environment == .sandbox || environment == .xcode
        #else
        return environment == .production || environment == .sandbox
        #endif
    }

    static func state() async -> PurchasePolicy.State {
        logger.notice("authorization check scope=\(Bundle.main.bundleIdentifier ?? "unknown", privacy: .public)")
        do {
            return try await StoreRequest.run {
                var unlock: PurchasePolicy.UnlockRecord?
                if case let .verified(transaction)? = await Transaction.latest(for: PurchasePolicy.productID) {
                    logger.notice("verified unlock environment=\(transaction.environment.rawValue, privacy: .public), revoked=\(transaction.revocationDate != nil, privacy: .public)")
                    unlock = .init(productID: transaction.productID,
                                   nonConsumable: transaction.productType == .nonConsumable,
                                   revoked: transaction.revocationDate != nil,
                                   trusted: accepts(transaction.environment))
                }
                // Permanent purchase remains usable if the app receipt query is unavailable.
                if PurchasePolicy.evaluate(app: nil, unlock: unlock, now: Date()) == .unlocked {
                    return .unlocked
                }
                var trial: PurchasePolicy.TrialRecord?
                if let result = await Transaction.latest(for: PurchasePolicy.trialProductID) {
                    guard case let .verified(transaction) = result else {
                        logger.notice("trial transaction is unverified")
                        return .unavailable
                    }
                    trial = .init(productID: transaction.productID,
                                  nonConsumable: transaction.productType == .nonConsumable,
                                  purchasedAt: transaction.purchaseDate,
                                  originalPurchasedAt: transaction.originalPurchaseDate,
                                  revoked: transaction.revocationDate != nil,
                                  trusted: accepts(transaction.environment))
                }
                guard case let .verified(app) = try await AppTransaction.shared else {
                    logger.notice("app transaction is unverified")
                    return .unavailable
                }
                logger.notice("verified app bundle=\(app.bundleID, privacy: .public), environment=\(app.environment.rawValue, privacy: .public)")
                return PurchasePolicy.evaluate(
                    app: .init(bundleID: app.bundleID, revoked: app.revocationDate != nil,
                               trusted: accepts(app.environment)),
                    unlock: unlock, trial: trial, now: Date())
            }
        } catch {
            let failure = error as NSError
            logger.error("authorization query failed domain=\(failure.domain, privacy: .public), code=\(failure.code, privacy: .public)")
            return .unavailable
        }
    }
}

// StoreKit requests may ignore cancellation. Resume once without waiting for a hung request.
private final class StoreRequestResult<Value>: @unchecked Sendable {
    private let lock = NSLock()
    private var continuation: CheckedContinuation<Value, Error>?

    init(_ continuation: CheckedContinuation<Value, Error>) {
        self.continuation = continuation
    }

    func finish(_ result: Result<Value, Error>) {
        lock.lock()
        let pending = continuation
        continuation = nil
        lock.unlock()
        pending?.resume(with: result)
    }
}

enum StoreRequest {
    static func run<Value>(seconds: TimeInterval = 30,
                           operation: @escaping () async throws -> Value) async throws -> Value {
        try await withCheckedThrowingContinuation { continuation in
            let result = StoreRequestResult(continuation)
            let task = Task {
                do { result.finish(.success(try await operation())) }
                catch { result.finish(.failure(error)) }
            }
            DispatchQueue.global().asyncAfter(deadline: .now() + seconds) {
                result.finish(.failure(NSError(domain: "MailTranslator.Store", code: 1,
                    userInfo: [NSLocalizedDescriptionKey: "App Store 请求超时，请重试"])))
                task.cancel()
            }
        }
    }
}
#endif
