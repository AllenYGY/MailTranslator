import StoreKit
import StoreKitTest
import XCTest

@MainActor
final class PurchaseTests: XCTestCase {
    private var session: SKTestSession!

    override func setUp() async throws {
        try await super.setUp()
        let config = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("Resources/MailTranslator.storekit")
        session = try SKTestSession(contentsOf: config)
        session.resetToDefaultState()
        session.disableDialogs = true
        session.storefront = "CHN"
        session.locale = Locale(identifier: "zh_CN")
        session.clearTransactions()
    }

    override func tearDown() async throws {
        session.clearTransactions()
        session = nil
        try await super.tearDown()
    }

    private func loadProduct() async throws -> Product {
        var product: Product?
        for _ in 0..<3 {
            product = try await Product.products(for: [PurchasePolicy.productID]).first
            if product != nil { break }
            try await Task.sleep(nanoseconds: 500_000_000)
        }
        return try XCTUnwrap(product)
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
