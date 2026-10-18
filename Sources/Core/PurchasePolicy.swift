import Foundation

enum PurchasePolicy {
    static let productID = "io.github.allenygy.mailtranslator.unlock"
    static let trialProductID = "io.github.allenygy.mailtranslator.trial7"
    static let trialDuration: TimeInterval = 7 * 24 * 60 * 60

    struct AppRecord {
        let bundleID: String
        let revoked: Bool
        let trusted: Bool
    }

    struct UnlockRecord {
        let productID: String
        let nonConsumable: Bool
        let revoked: Bool
        let trusted: Bool
    }

    struct TrialRecord {
        let productID: String
        let nonConsumable: Bool
        let purchasedAt: Date
        let originalPurchasedAt: Date
        let revoked: Bool
        let trusted: Bool
    }

    enum State: Equatable {
        case unlocked
        case notStarted
        case trial(until: Date)
        case expired
        case unavailable

        var canTranslate: Bool {
            switch self {
            case .unlocked, .trial: return true
            case .notStarted, .expired, .unavailable: return false
            }
        }
    }

    static func evaluate(app: AppRecord?, unlock: UnlockRecord?, trial: TrialRecord? = nil, now: Date) -> State {
        if let unlock, unlock.trusted, !unlock.revoked, unlock.nonConsumable,
           unlock.productID == productID {
            return .unlocked
        }
        guard let app, app.trusted, !app.revoked, app.bundleID == BundleID.app else { return .unavailable }
        guard let trial else { return .notStarted }
        guard trial.trusted, !trial.revoked, trial.nonConsumable,
              trial.productID == trialProductID,
              trial.originalPurchasedAt <= trial.purchasedAt,
              trial.purchasedAt <= now else { return .unavailable }
        // A restored non-consumable keeps its original date, never the restore date.
        let end = trial.originalPurchasedAt.addingTimeInterval(trialDuration)
        return now < end ? .trial(until: end) : .expired
    }
}
