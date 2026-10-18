import StoreKit
import StoreKitTest
import XCTest

@MainActor
final class PurchaseTests: XCTestCase {
    private var session: SKTestSession!

    override func setUp() async throws {
        try await super.setUp()
        let config = try XCTUnwrap(
            Bundle(for: PurchaseTests.self).url(forResource: "MailTranslator", withExtension: "storekit"),
            "The StoreKit fixture must be included in the test bundle's resources"
        )
        session = try SKTestSession(contentsOf: config)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.storefront = "CHN"
        session.locale = Locale(identifier: "zh_CN")
        session.clearTransactions()
    }

    override func tearDown() async throws {
        session?.clearTransactions()
        session = nil
        try await super.tearDown()
    }

    private func loadProduct(_ id: String = PurchasePolicy.productID) async throws -> Product {
        var product: Product?
        for _ in 0..<3 {
            product = try await Product.products(for: [id]).first
            if product != nil { break }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        return try XCTUnwrap(product)
    }

    private func claimTrial() async throws -> Transaction {
        let item = try await loadProduct(PurchasePolicy.trialProductID)
        XCTAssertEqual(item.type, .nonConsumable)
        XCTAssertEqual(item.price, 0, "The trial must never charge")
        XCTAssertEqual(item.displayName, "7 天免费试用")
        guard case let .success(result) = try await item.purchase(),
              case let .verified(transaction) = result else {
            throw NSError(domain: "PurchaseTests", code: 1,
                          userInfo: [NSLocalizedDescriptionKey: "Expected verified free trial"])
        }
        await transaction.finish()
        return transaction
    }

    private func trialRecord(_ transaction: Transaction) -> PurchasePolicy.TrialRecord {
        .init(productID: transaction.productID, nonConsumable: transaction.productType == .nonConsumable,
              purchasedAt: transaction.purchaseDate, originalPurchasedAt: transaction.originalPurchaseDate,
              revoked: transaction.revocationDate != nil,
              trusted: StorePurchaseAccess.accepts(transaction.environment))
    }

    func testFreeTrialUsesSignedOriginalDateAndRequiresAppIdentity() async throws {
        let transaction = try await claimTrial()
        let trial = trialRecord(transaction)
        let end = transaction.originalPurchaseDate.addingTimeInterval(PurchasePolicy.trialDuration)
        let access = await StorePurchaseAccess.state()
        XCTAssertEqual(access, .trial(until: end))
        let app = PurchasePolicy.AppRecord(bundleID: BundleID.app, revoked: false, trusted: true)
        XCTAssertEqual(PurchasePolicy.evaluate(app: app, unlock: nil, trial: trial,
            now: transaction.purchaseDate), .trial(until: end))
        XCTAssertEqual(PurchasePolicy.evaluate(app: app, unlock: nil, trial: trial, now: end), .expired)
        XCTAssertEqual(PurchasePolicy.evaluate(app: nil, unlock: nil, trial: trial,
            now: transaction.purchaseDate), .unavailable)
    }

    func testRestoreAndRediscoveryDoNotResetTrial() async throws {
        let original = try await claimTrial()
        let originalEnd = original.originalPurchaseDate.addingTimeInterval(PurchasePolicy.trialDuration)
        try await AppStore.sync()
        guard case let .verified(restored)? = await Transaction.latest(for: PurchasePolicy.trialProductID) else {
            XCTFail("Restore must rediscover the signed non-consumable trial")
            return
        }
        XCTAssertEqual(restored.originalPurchaseDate, original.originalPurchaseDate)
        let app = PurchasePolicy.AppRecord(bundleID: BundleID.app, revoked: false, trusted: true)
        XCTAssertEqual(PurchasePolicy.evaluate(app: app, unlock: nil, trial: trialRecord(restored),
            now: originalEnd), .expired)
        XCTAssertEqual(session.allTransactions().count, 1, "Restore must not create another trial")
    }

    func testRefundedTrialCannotGrantAccess() async throws {
        let claimed = try await claimTrial()
        let beforeRefund = await StorePurchaseAccess.state()
        XCTAssertEqual(beforeRefund, .trial(until:
            claimed.originalPurchaseDate.addingTimeInterval(PurchasePolicy.trialDuration)))
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        try await AppStore.sync()
        var revoked: Transaction?
        for _ in 0..<100 {
            if case let .verified(latest)? = await Transaction.latest(for: PurchasePolicy.trialProductID),
               latest.revocationDate != nil {
                revoked = latest
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        let refunded = try XCTUnwrap(revoked, "StoreKit must deliver the signed trial revocation")
        let app = PurchasePolicy.AppRecord(bundleID: BundleID.app, revoked: false, trusted: true)
        XCTAssertEqual(PurchasePolicy.evaluate(app: app, unlock: nil, trial: trialRecord(refunded),
            now: Date()), .unavailable)
        let access = await StorePurchaseAccess.state()
        XCTAssertEqual(access, .unavailable)
    }

    func testPendingTrialDoesNotGrantAccess() async throws {
        session.askToBuyEnabled = true
        let item = try await loadProduct(PurchasePolicy.trialProductID)
        guard case .pending = try await item.purchase() else {
            XCTFail("Expected pending free-trial approval")
            return
        }
        if case .verified? = await Transaction.latest(for: PurchasePolicy.trialProductID) {
            XCTFail("Pending trial must not create a verified transaction")
        }
        let access = await StorePurchaseAccess.state()
        XCTAssertFalse(access.canTranslate)
    }

    func testProductPurchaseAndRediscovery() async throws {
        let item = try await loadProduct()
        XCTAssertEqual(item.type, .nonConsumable)
        switch try await item.purchase() {
        case let .success(result):
            guard case let .verified(transaction) = result else {
                XCTFail("StoreKit must verify the purchase")
                return
            }
            await transaction.finish()
        default: XCTFail("Expected completed purchase")
        }
        let access = await StorePurchaseAccess.state()
        XCTAssertEqual(access, .unlocked)
        try await AppStore.sync()
        let restored = await StorePurchaseAccess.state()
        XCTAssertEqual(restored, .unlocked)
    }

    func testRefundDoesNotGrantPermanentAccess() async throws {
        let product = try await loadProduct()
        guard case let .success(result) = try await product.purchase(),
              case let .verified(purchased) = result else {
            XCTFail("Expected verified purchase before refund")
            return
        }
        await purchased.finish()
        let beforeRefund = await StorePurchaseAccess.state()
        XCTAssertEqual(beforeRefund, .unlocked)
        let transaction = try XCTUnwrap(session.allTransactions().first)
        try session.refundTransaction(identifier: transaction.identifier)
        try await AppStore.sync()
        var revoked = false
        for _ in 0..<100 {
            if case let .verified(latest)? = await Transaction.latest(for: PurchasePolicy.productID),
               latest.revocationDate != nil {
                revoked = true
                break
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertTrue(revoked, "StoreKit must deliver the signed refund")
        let access = await StorePurchaseAccess.state()
        XCTAssertNotEqual(access, .unlocked)
    }

    func testRestoreRediscoversVerifiedPurchase() async throws {
        let item = try await loadProduct()
        guard case let .success(result) = try await item.purchase(),
              case let .verified(transaction) = result else {
            XCTFail("Expected verified purchase before restoring")
            return
        }
        await transaction.finish()
        let restored = try await StorePurchaseAccess.restore()
        XCTAssertEqual(restored, .unlocked)
        XCTAssertEqual(session.allTransactions().count, 1, "Restore must not repurchase")
    }

    func testRestoreWithoutPurchaseDoesNotUnlock() async throws {
        let restored = try await StorePurchaseAccess.restore()
        XCTAssertNotEqual(restored, .unlocked)
        XCTAssertTrue(session.allTransactions().isEmpty)
    }

    func testPendingPurchaseRequiresApproval() async throws {
        session.askToBuyEnabled = true
        let item = try await loadProduct()
        guard case .pending = try await item.purchase() else {
            XCTFail("Expected pending approval")
            return
        }
        if case let .verified(transaction)? = await Transaction.latest(for: PurchasePolicy.productID) {
            XCTFail("Pending transaction must not grant a verified unlock: \(transaction.id)")
        }
        let pending = try XCTUnwrap(session.allTransactions().first)
        try session.approveAskToBuyTransaction(identifier: pending.identifier)
        try await AppStore.sync()
        let access = await StorePurchaseAccess.state()
        XCTAssertEqual(access, .unlocked)
    }

    func testFailedPurchaseDoesNotCreatePurchase() async throws {
        try await session.setSimulatedError(.generic(.userCancelled), forAPI: StoreKitPurchaseAPI())
        let item = try await loadProduct()
        do {
            guard case .userCancelled = try await item.purchase() else {
                XCTFail("Expected cancellation")
                return
            }
        } catch {
            // Xcode 27 may map the simulated cancellation to StoreKitError.unknown.
            // Regardless of the error code, failure must not create a transaction.
        }
        XCTAssertTrue(session.allTransactions().isEmpty)
    }
}
