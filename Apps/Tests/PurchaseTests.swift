import XCTest
@testable import Batwalk

final class PurchaseTests: XCTestCase {
    @MainActor
    func testPendingAndCancelledNeverGrantUnlock() async throws {
        let backend = FakePurchaseBackend()
        let manager = PurchaseManager(backend: backend)
        await manager.loadProduct()
        backend.outcome = .pending
        await manager.purchase()
        XCTAssertFalse(manager.isUnlocked)
        XCTAssertTrue(manager.message?.contains("approval") == true)
        XCTAssertFalse(manager.isBusy)
        backend.outcome = .cancelled
        await manager.purchase()
        XCTAssertFalse(manager.isUnlocked)
        XCTAssertEqual(manager.message, "Purchase cancelled.")
    }

    @MainActor
    func testPurchaseRestoreAndRevocationFollowVerifiedBackend() async throws {
        let backend = FakePurchaseBackend(); let manager = PurchaseManager(backend: backend)
        await manager.loadProduct()
        backend.unlocked = true
        await manager.purchase()
        XCTAssertTrue(manager.isUnlocked)
        backend.unlocked = false
        await manager.refreshEntitlements()
        XCTAssertFalse(manager.isUnlocked)
        backend.unlocked = true
        await manager.restore()
        XCTAssertTrue(manager.isUnlocked)
        XCTAssertEqual(manager.message, "Full unlock restored.")
        backend.unlocked = false
        await manager.restore()
        XCTAssertTrue(manager.message?.contains("No full unlock") == true)
    }

    @MainActor
    func testOfflineRestoreRetainsPreviouslyVerifiedUnlockAndAllowsRetry() async throws {
        let backend = FakePurchaseBackend(); let manager = PurchaseManager(backend: backend)
        backend.unlocked = true
        await manager.refreshEntitlements()
        backend.fail = true
        await manager.restore()
        XCTAssertTrue(manager.isUnlocked)
        XCTAssertNotNil(manager.lastError)
        XCTAssertFalse(manager.isBusy)
        backend.fail = false
        await manager.restore()
        XCTAssertNil(manager.lastError)
    }

    @MainActor
    func testUnavailableOfferDoesNotAttemptPurchase() async throws {
        let backend = FakePurchaseBackend(); backend.offer = nil
        let manager = PurchaseManager(backend: backend)
        await manager.loadProduct(); await manager.purchase()
        XCTAssertEqual(backend.buyCalls, 0)
        XCTAssertNotNil(manager.lastError)
        backend.offer = PurchaseOffer(displayPrice: "€2.49")
        await manager.loadProduct()
        XCTAssertEqual(manager.product?.displayPrice, "€2.49")
        XCTAssertNil(manager.lastError)
    }
}

@MainActor
private final class FakePurchaseBackend: PurchaseBackend {
    var offer: PurchaseOffer? = PurchaseOffer(displayPrice: "$1.99")
    var outcome: PurchaseOutcome = .purchased
    var unlocked = false
    var fail = false
    var buyCalls = 0
    func loadOffer() async throws -> PurchaseOffer? { if fail { throw Failure.offline }; return offer }
    func hasUnlock() async -> Bool { unlocked }
    func buy() async throws -> PurchaseOutcome { buyCalls += 1; if fail { throw Failure.offline }; return outcome }
    func restore() async throws { if fail { throw Failure.offline } }
    enum Failure: Error { case offline }
}
