import XCTest
import UIKit
import BatwalkCore
@testable import Batwalk

final class WalkingTogetherTests: XCTestCase {
    private let now = ISO8601DateFormatter().date(from: "2026-10-23T12:00:00Z")!
    private var suites: [String] = []

    override func tearDown() {
        for name in suites { UserDefaults.standard.removePersistentDomain(forName: name) }
        super.tearDown()
    }

    @MainActor
    private func coordinator(_ backend: FakeWalkingBackend, monthly: Bool = false, total: Bool = false) -> WalkingTogetherCoordinator {
        let suite = "WalkingTogetherTests.\(UUID().uuidString)"
        suites.append(suite)
        let defaults = UserDefaults(suiteName: suite)!
        defaults.set(monthly, forKey: WalkingTogetherCoordinator.monthlyKey)
        defaults.set(total, forKey: WalkingTogetherCoordinator.totalKey)
        if monthly || total { defaults.set("me", forKey: WalkingTogetherCoordinator.accountKey) }
        return WalkingTogetherCoordinator(backend: backend, defaults: defaults, available: true, now: { self.now })
    }

    @MainActor
    func testOffMakesNoAuthenticationQueryOrSubmission() async {
        let backend = FakeWalkingBackend()
        let subject = coordinator(backend)
        await subject.refresh(history: [], total: 800)
        XCTAssertEqual(subject.status, .off)
        XCTAssertEqual(backend.authentications, 0)
        XCTAssertTrue(backend.submissions.isEmpty)
        XCTAssertTrue(backend.queries.isEmpty)
    }

    @MainActor
    func testExplicitChoiceSubmitsOnlyThatGameScoreAndNoSteps() async {
        let backend = FakeWalkingBackend()
        let subject = coordinator(backend)
        let record = HatchRecord(speciesID: "mochi", isShiny: false, eggType: .tiny,
                                 hatchedAt: now, outcome: .duplicate)
        await subject.setSharing(.month, enabled: true, history: [record], total: 500)
        XCTAssertEqual(backend.submissions, [HatchLeaderboardScore(board: .month, value: 1, context: 202610)])
        XCTAssertEqual(backend.queries.map(\.board), [.month])
        await subject.refresh(history: [record], total: 500)
        XCTAssertEqual(backend.submissions.count, 1) // Same snapshot is not re-posted.
        await subject.setSharing(.month, enabled: false, history: [record], total: 500)
        await subject.refresh(history: [record, record], total: 501)
        XCTAssertEqual(backend.submissions.count, 1)
        XCTAssertTrue(subject.rows.isEmpty)
    }

    @MainActor
    func testTrimmedHistorySubmitsPersistedCurrentMonthCount() async {
        let backend = FakeWalkingBackend()
        let subject = coordinator(backend, monthly: true)
        await subject.refresh(history: [], total: 200, monthlyCounts: ["202609": 90, "202610": 8])
        XCTAssertEqual(backend.submissions, [HatchLeaderboardScore(board: .month, value: 8, context: 202610)])
    }

    @MainActor
    func testAllFriendPagesLoadBeforeMonthContextFiltering() async {
        let backend = FakeWalkingBackend()
        backend.entries = (0..<205).map {
            WalkingEntry(player: WalkingAccount(id: "friend-\($0)", name: "Friend \($0)"),
                         score: 205 - $0, context: $0 == 204 ? 202610 : 202609)
        }
        let subject = coordinator(backend, monthly: true)
        await subject.refresh(history: [], total: 0)
        XCTAssertEqual(backend.queries.map(\.start), [1, 101, 201])
        XCTAssertTrue(backend.queries.allSatisfy { $0.count == 100 && $0.board == .month })
        XCTAssertEqual(subject.rows.count, 205)
        XCTAssertEqual(subject.rows.first?.id, "friend-204")
        XCTAssertEqual(subject.rows.first?.month, 1)
        XCTAssertNil(subject.rows.first(where: { $0.id == "friend-0" })?.month)
    }

    @MainActor
    func testRevokedFriendsAccessClearsRowsAndSkipsSubmission() async {
        let backend = FakeWalkingBackend()
        backend.entries = [WalkingEntry(player: WalkingAccount(id: "friend", name: "Fern"), score: 3, context: 202610)]
        let subject = coordinator(backend, monthly: true)
        await subject.refresh(history: [], total: 0)
        XCTAssertFalse(subject.rows.isEmpty)
        backend.permission = false
        await subject.refresh(history: [], total: 2)
        XCTAssertTrue(subject.rows.isEmpty)
        XCTAssertEqual(subject.status, .friendsPermission)
        XCTAssertEqual(backend.submissions.count, 1)
        XCTAssertGreaterThan(backend.cacheClears, 0)
    }

    @MainActor
    func testAccountChangeTurnsOffConsentAndNeverPostsToNewAccount() async {
        let backend = FakeWalkingBackend()
        let subject = coordinator(backend, total: true)
        await subject.refresh(history: [], total: 12)
        backend.account = WalkingAccount(id: "another-account", name: "Another player")
        backend.authenticationChanged?()
        await subject.refresh(history: [], total: 90)
        XCTAssertFalse(subject.totalEnabled)
        XCTAssertFalse(subject.monthlyEnabled)
        XCTAssertEqual(backend.submissions.count, 1)
        XCTAssertTrue(subject.rows.isEmpty)
    }

    @MainActor
    func testOptOutWhileFriendQueryIsInFlightCannotRepublishRows() async {
        let backend = FakeWalkingBackend()
        backend.entries = [WalkingEntry(player: WalkingAccount(id: "friend", name: "Fern"), score: 3, context: 202610)]
        let subject = coordinator(backend, monthly: true)
        backend.beforeReturningPage = {
            await subject.setSharing(.month, enabled: false, history: [], total: 0)
        }
        await subject.refresh(history: [], total: 0)
        XCTAssertEqual(subject.status, .off)
        XCTAssertTrue(subject.rows.isEmpty)
    }

    @MainActor
    func testAccountRevocationDuringSubmissionStopsRemainingBoards() async {
        let backend = FakeWalkingBackend()
        let subject = coordinator(backend, monthly: true, total: true)
        backend.afterSubmission = {
            backend.account = nil
            backend.authenticationChanged?()
        }
        await subject.refresh(history: [], total: 100)
        XCTAssertEqual(backend.submissions.map(\.board), [.month])
        XCTAssertTrue(backend.queries.isEmpty)
        XCTAssertFalse(subject.isSharing)
    }

    @MainActor
    func testDuplicateLocalRowIsMergedAndHighlightedWithoutRank() async {
        let backend = FakeWalkingBackend()
        backend.entries = [WalkingEntry(player: backend.account!, score: 4, context: 202610)]
        backend.local = backend.entries[0]
        let subject = coordinator(backend, monthly: true)
        await subject.refresh(history: [], total: 4)
        XCTAssertEqual(subject.rows.count, 1)
        XCTAssertTrue(subject.rows[0].isMe)
    }
}

@MainActor
private final class FakeWalkingBackend: WalkingTogetherBackend {
    struct Query { let board: HatchLeaderboard; let start: Int; let count: Int }
    var account: WalkingAccount? = WalkingAccount(id: "me", name: "Mochi's friend")
    var authenticationChanged: (() -> Void)?
    var permission = true
    var authentications = 0
    var cacheClears = 0
    var submissions: [HatchLeaderboardScore] = []
    var queries: [Query] = []
    var entries: [WalkingEntry] = []
    var local: WalkingEntry?
    var beforeReturningPage: (() async -> Void)?
    var afterSubmission: (() async -> Void)?
    func authenticate(interactively: Bool) async throws { authentications += 1 }
    func friendsAllowed(requestIfNeeded: Bool) async throws -> Bool { permission }
    func submit(_ score: HatchLeaderboardScore) async throws {
        submissions.append(score)
        await afterSubmission?()
    }
    func friends(board: HatchLeaderboard, start: Int, count: Int) async throws -> WalkingPage {
        queries.append(Query(board: board, start: start, count: count))
        await beforeReturningPage?()
        return WalkingPage(local: local, entries: Array(entries.dropFirst(start - 1).prefix(count)), total: entries.count)
    }
    func photo(playerID: String) async -> UIImage? { nil }
    func discardCachedFriends() { cacheClears += 1 }
}
