import XCTest
@testable import BatwalkCore

final class CompanionHandoffTests: XCTestCase {
    private let now = Date(timeIntervalSince1970: 1_000_000)

    private func state() throws -> GameState {
        var state = GameState()
        state.start(seed: 1, now: now)
        state.ingestSteps(dayKey: "2026-10-10", dailyTotal: 2_000)
        _ = try state.hatch(now: now)
        state.advanceRevision()
        return state
    }

    func testReceiptBeforeSaveWaitsForCommittedRevision() throws {
        let old = try state()
        let request = CompanionChangeRequest(speciesID: "mochi", saveID: old.saveID, requestedAt: now)
        var handoff = CompanionHandoff(); XCTAssertTrue(handoff.begin(request))
        handoff.receive(CompanionChangeReceipt(request: request, outcome: .applied, revision: 2), state: old, now: now)
        XCTAssertTrue(handoff.isWaiting)
        var updated = old; updated.advanceRevision()
        handoff.reconcile(with: updated, now: now)
        XCTAssertNil(handoff.request)
    }

    func testSaveBeforeReceiptDoesNotPretendQueueWasAcknowledged() throws {
        var state = try state()
        let request = CompanionChangeRequest(speciesID: "mochi", saveID: state.saveID, requestedAt: now)
        var handoff = CompanionHandoff(); handoff.begin(request)
        state.advanceRevision()
        handoff.reconcile(with: state, now: now)
        XCTAssertTrue(handoff.isWaiting)
        handoff.receive(CompanionChangeReceipt(request: request, outcome: .applied, revision: 2), state: state, now: now)
        XCTAssertNil(handoff.request)
    }

    func testAnotherRequestCannotReplacePendingIntent() throws {
        let state = try state()
        let request = CompanionChangeRequest(speciesID: "mochi", saveID: state.saveID, requestedAt: now)
        var handoff = CompanionHandoff(); handoff.begin(request)
        XCTAssertFalse(handoff.begin(CompanionChangeRequest(speciesID: "sticky", saveID: state.saveID, requestedAt: now)))
        XCTAssertEqual(handoff.request, request)
    }

    func testUnrelatedReceiptIsIgnored() throws {
        let state = try state()
        let request = CompanionChangeRequest(speciesID: "mochi", saveID: state.saveID, requestedAt: now)
        var handoff = CompanionHandoff(); handoff.begin(request)
        let other = CompanionChangeRequest(speciesID: "sticky", saveID: state.saveID, requestedAt: now)
        handoff.receive(CompanionChangeReceipt(request: other, outcome: .applied, revision: 1), state: state, now: now)
        XCTAssertTrue(handoff.isWaiting); XCTAssertNil(handoff.receipt)
    }

    func testExpiryAllowsAnExplicitNewRequest() throws {
        let state = try state()
        let request = CompanionChangeRequest(speciesID: "mochi", saveID: state.saveID, requestedAt: now)
        var handoff = CompanionHandoff(); handoff.begin(request)
        handoff.reconcile(with: state, now: request.expiresAt)
        XCTAssertEqual(handoff.failure, .expired)
        XCTAssertTrue(handoff.begin(CompanionChangeRequest(speciesID: "mochi", saveID: state.saveID, requestedAt: request.expiresAt)))
    }

    func testWatchRejectionIsNotSuccess() throws {
        let state = try state()
        let request = CompanionChangeRequest(speciesID: "sticky", saveID: state.saveID, requestedAt: now)
        var handoff = CompanionHandoff(); handoff.begin(request)
        handoff.receive(CompanionChangeReceipt(request: request, outcome: .saveFailed, revision: 1), state: state, now: now)
        XCTAssertEqual(handoff.failure, .saveFailed); XCTAssertFalse(handoff.isWaiting)
    }

    func testNewerWatchChoiceSupersedesReceipt() throws {
        let state = try state()
        let request = CompanionChangeRequest(speciesID: "sticky", saveID: state.saveID, requestedAt: now)
        var handoff = CompanionHandoff(); handoff.begin(request)
        handoff.receive(CompanionChangeReceipt(request: request, outcome: .applied, revision: 1), state: state, now: now)
        XCTAssertEqual(handoff.failure, .superseded)
    }

    func testWatchResetDoesNotApplyOldSaveIntent() throws {
        let state = try state()
        var handoff = CompanionHandoff()
        handoff.begin(CompanionChangeRequest(speciesID: "mochi", saveID: state.saveID, requestedAt: now))
        handoff.reconcile(with: GameState(), now: now)
        XCTAssertEqual(handoff.failure, .saveChanged)
    }

    func testPendingAndReceiptSurviveEncoding() throws {
        let state = try state()
        var handoff = CompanionHandoff()
        let request = CompanionChangeRequest(speciesID: "mochi", saveID: state.saveID, requestedAt: now)
        handoff.begin(request)
        handoff.receive(CompanionChangeReceipt(request: request, outcome: .applied, revision: 2), state: state, now: now)
        let reload = try JSONDecoder().decode(CompanionHandoff.self, from: JSONEncoder().encode(handoff))
        XCTAssertEqual(reload, handoff); XCTAssertTrue(reload.isWaiting)
    }
}

