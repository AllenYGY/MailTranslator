import Foundation

enum PurchasePolicy {
    static let productID = "io.github.allenygy.mailtranslator.unlock"
    static let trialDuration: TimeInterval = 7 * 24 * 60 * 60

    struct AppRecord {
        let bundleID: String
        let purchasedAt: Date
        let revoked: Bool
        let trusted: Bool
    }

    struct UnlockRecord {
        let productID: String
        let nonConsumable: Bool
        let revoked: Bool
        let trusted: Bool
    }

    enum State: Equatable {
        case unlocked
        case trial(until: Date)
        case expired
        case unavailable

        var canTranslate: Bool {
            switch self {
            case .unlocked, .trial: return true
            case .expired, .unavailable: return false
            }
        }
    }

    static func evaluate(app: AppRecord?, unlock: UnlockRecord?, now: Date) -> State {
        if let unlock, unlock.trusted, !unlock.revoked, unlock.nonConsumable,
           unlock.productID == productID {
            return .unlocked
        }
        guard let app, app.trusted, !app.revoked, app.bundleID == BundleID.app,
              app.purchasedAt <= now else { return .unavailable }
        let end = app.purchasedAt.addingTimeInterval(trialDuration)
        return now < end ? .trial(until: end) : .expired
    }
}
