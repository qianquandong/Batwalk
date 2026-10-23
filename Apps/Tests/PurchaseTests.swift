import XCTest
@testable import Batwalk

final class PurchaseTests: XCTestCase {
    @MainActor
    func testFreeLaunchMakesNoStoreKitCallsEvenWhenRequested() async {
        XCTAssertFalse(SharedConfig.paidContentEnabled)
        let backend = FakePurchaseBackend()
        backend.state = .active
        let manager = PurchaseManager(backend: backend)
        manager.start()
        await manager.loadProduct()
        await manager.refreshEntitlements()
        await manager.purchase()
        await manager.restore()
        XCTAssertEqual(backend.totalCalls, 0)
        XCTAssertFalse(manager.hasCheckedEntitlements)
        XCTAssertNil(manager.product)
        XCTAssertNil(EntitlementPolicy.unlockedValue(for: .active))
        XCTAssertNil(EntitlementPolicy.unlockedValue(for: .revoked))
    }

    @MainActor
    func testPendingAndCancelledNeverGrantUnlock() async throws {
        let backend = FakePurchaseBackend()
        let manager = PurchaseManager(backend: backend, paidContentEnabled: true)
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
        let backend = FakePurchaseBackend(); let manager = PurchaseManager(backend: backend, paidContentEnabled: true)
        await manager.loadProduct()
        backend.state = .active
        await manager.purchase()
        XCTAssertTrue(manager.isUnlocked)
        backend.state = .revoked
        await manager.refreshEntitlements()
        XCTAssertFalse(manager.isUnlocked)
        XCTAssertEqual(manager.entitlement, .revoked)
        backend.state = .active
        await manager.restore()
        XCTAssertTrue(manager.isUnlocked)
        XCTAssertEqual(manager.message, "Full unlock restored.")
        backend.state = .none
        await manager.restore()
        XCTAssertTrue(manager.message?.contains("No full unlock") == true)
    }

    @MainActor
    func testEveryCheckBumpsTheVersionSoTheSaveCanBeReapplied() async throws {
        let backend = FakePurchaseBackend(); let manager = PurchaseManager(backend: backend, paidContentEnabled: true)
        XCTAssertEqual(manager.entitlementVersion, 0)
        await manager.refreshEntitlements()
        await manager.refreshEntitlements()
        XCTAssertEqual(manager.entitlementVersion, 2)
        XCTAssertTrue(manager.hasCheckedEntitlements)
    }

    func testOnlyVerifiedResultsChangeTheSave() {
        XCTAssertEqual(EntitlementPolicy.unlockedValue(for: .active, paidContentEnabled: true), true)
        XCTAssertEqual(EntitlementPolicy.unlockedValue(for: .revoked, paidContentEnabled: true), false)
        XCTAssertNil(EntitlementPolicy.unlockedValue(for: .none, paidContentEnabled: true), "an unknown result must never re-lock a paying player")
    }

    @MainActor
    func testOfflineRestoreRetainsPreviouslyVerifiedUnlockAndAllowsRetry() async throws {
        let backend = FakePurchaseBackend(); let manager = PurchaseManager(backend: backend, paidContentEnabled: true)
        backend.state = .active
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
        let manager = PurchaseManager(backend: backend, paidContentEnabled: true)
        await manager.loadProduct(); await manager.purchase()
        XCTAssertEqual(backend.buyCalls, 0)
        XCTAssertNotNil(manager.lastError)
        backend.offer = PurchaseOffer(displayPrice: "€3.49")
        await manager.loadProduct()
        XCTAssertEqual(manager.product?.displayPrice, "€3.49")
        XCTAssertNil(manager.lastError)
    }
}

@MainActor
private final class FakePurchaseBackend: PurchaseBackend {
    var offer: PurchaseOffer? = PurchaseOffer(displayPrice: "$2.99")
    var outcome: PurchaseOutcome = .purchased
    var state: EntitlementState = .none
    var fail = false
    var totalCalls = 0
    var buyCalls = 0
    func loadOffer() async throws -> PurchaseOffer? { totalCalls += 1; if fail { throw Failure.offline }; return offer }
    func entitlement() async -> EntitlementState { totalCalls += 1; return state }
    func buy() async throws -> PurchaseOutcome { totalCalls += 1; buyCalls += 1; if fail { throw Failure.offline }; return outcome }
    func restore() async throws { totalCalls += 1; if fail { throw Failure.offline } }
    enum Failure: Error { case offline }
}
