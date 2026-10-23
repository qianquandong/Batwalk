import Foundation
import Observation
import UIKit
import BatwalkCore

struct WalkingAccount: Equatable {
    let id: String
    let name: String
}

struct WalkingEntry: Equatable {
    let player: WalkingAccount
    let score: Int
    let context: Int
}

struct WalkingPage {
    let local: WalkingEntry?
    let entries: [WalkingEntry]
    let total: Int
    let ranksRead: Int
    init(local: WalkingEntry?, entries: [WalkingEntry], total: Int, ranksRead: Int? = nil) {
        self.local = local; self.entries = entries; self.total = total
        self.ranksRead = ranksRead ?? entries.count
    }
}

/// The backend cannot accept a raw save, Health sample, or step score.
@MainActor
protocol WalkingTogetherBackend: AnyObject {
    var account: WalkingAccount? { get }
    var authenticationChanged: (() -> Void)? { get set }
    func authenticate(interactively: Bool) async throws
    func friendsAllowed(requestIfNeeded: Bool) async throws -> Bool
    func submit(_ score: HatchLeaderboardScore) async throws
    func friends(board: HatchLeaderboard, start: Int, count: Int) async throws -> WalkingPage
    func photo(playerID: String) async -> UIImage?
    func discardCachedFriends()
}

struct WalkingFriend: Identifiable, Equatable {
    let id: String
    let name: String
    let isMe: Bool
    var month: Int?
    var total: Int?
}

@MainActor
@Observable
final class WalkingTogetherCoordinator {
    enum Status: Equatable { case off, unavailable, signIn, friendsPermission, loading, ready, failed }
    private(set) var status: Status = .off
    private(set) var monthlyEnabled = false
    private(set) var totalEnabled = false
    private(set) var rows: [WalkingFriend] = []
    private(set) var account: WalkingAccount?
    private(set) var monthContext = 0
    let available: Bool
    @ObservationIgnored private let backend: any WalkingTogetherBackend
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let now: () -> Date
    @ObservationIgnored private var consentAccountID: String?
    @ObservationIgnored private var generation = 0
    @ObservationIgnored private var sent: [String: HatchLeaderboardScore] = [:]

    static let monthlyKey = "batwalk.friends.monthly"
    static let totalKey = "batwalk.friends.total"
    static let accountKey = "batwalk.friends.account"

    init(backend: (any WalkingTogetherBackend)? = nil, defaults: UserDefaults = .standard,
         available: Bool = SharedConfig.gameCenterEnabled, now: @escaping () -> Date = Date.init) {
        let demo = DemoMode.scenario == "phone-friends"
        if let backend { self.backend = backend }
        else if demo { self.backend = DemoWalkingBackend() }
        else { self.backend = GameCenterWalkingBackend() }
        self.defaults = defaults
        self.available = available || demo
        self.now = now
        monthlyEnabled = defaults.bool(forKey: Self.monthlyKey)
        totalEnabled = defaults.bool(forKey: Self.totalKey)
        consentAccountID = defaults.string(forKey: Self.accountKey)
        if consentAccountID == nil { monthlyEnabled = false; totalEnabled = false }
        if demo {
            monthlyEnabled = true; totalEnabled = true
            consentAccountID = "demo-me"
        }
        status = self.available ? .off : .unavailable
        self.backend.authenticationChanged = { [weak self] in self?.authenticationDidChange() }
    }

    var isSharing: Bool { monthlyEnabled || totalEnabled }

    func setSharing(_ board: HatchLeaderboard, enabled: Bool, history: [HatchRecord], total: Int, monthlyCounts: [String: Int] = [:]) async {
        guard available else { status = .unavailable; return }
        generation += 1
        let action = generation
        if !enabled {
            if board == .month { monthlyEnabled = false } else { totalEnabled = false }
            sent.removeAll(); rows.removeAll(); backend.discardCachedFriends()
            if !isSharing { consentAccountID = nil; status = .off }
            else { status = .ready }
            persistConsent()
            return
        }
        do {
            try await backend.authenticate(interactively: true)
            guard generation == action else { return }
            guard let player = backend.account else { status = .signIn; return }
            // A foreground/account notification can arrive after this user action.
            // The new account receives only the switch explicitly chosen now.
            if let consentAccountID, consentAccountID != player.id {
                monthlyEnabled = false; totalEnabled = false
                sent.removeAll(); rows.removeAll(); backend.discardCachedFriends()
            }
            // An explicit toggle binds this consent to this Game Center account.
            account = player; consentAccountID = player.id
            if board == .month { monthlyEnabled = true } else { totalEnabled = true }
            persistConsent()
            await refresh(history: history, total: total, monthlyCounts: monthlyCounts, interactive: true)
        } catch { if generation == action { status = .signIn } }
    }

    func refresh(history: [HatchRecord], total: Int, monthlyCounts: [String: Int] = [:], interactive: Bool = false) async {
        guard available, isSharing else { status = available ? .off : .unavailable; return }
        generation += 1
        let operation = generation
        status = .loading
        do {
            try await backend.authenticate(interactively: interactive)
            guard active(operation), let player = backend.account else {
                if generation == operation { status = .signIn }
                return
            }
            guard player.id == consentAccountID else { stopForAccountChange(); return }
            account = player
            let permitted = try await backend.friendsAllowed(requestIfNeeded: interactive)
            guard active(operation, playerID: player.id) else { return }
            guard permitted else { rows.removeAll(); backend.discardCachedFriends(); status = .friendsPermission; return }
            let date = now()
            monthContext = HatchLeaderboards.monthKey(at: date)
            let scores = [HatchLeaderboards.monthlyScore(history: history, now: date, savedCounts: monthlyCounts),
                          HatchLeaderboards.totalScore(hatchCount: total)]
            for score in scores where enabled(score.board) {
                guard active(operation, playerID: player.id) else { return }
                guard HatchLeaderboards.isCurrent(score, at: now()) else { status = .failed; return }
                let key = player.id + ":" + score.board.rawValue
                if sent[key] != score {
                    try await backend.submit(score)
                    guard active(operation, playerID: player.id) else { return }
                    sent[key] = score
                }
            }
            var combined: [String: WalkingFriend] = [:]
            for board in HatchLeaderboard.allCases where enabled(board) {
                var start = 1
                repeat {
                    let page = try await backend.friends(board: board, start: start, count: 100)
                    guard active(operation, playerID: player.id) else { return }
                    guard monthContext == HatchLeaderboards.monthKey(at: now()) else {
                        rows.removeAll(); status = .failed; return
                    }
                    for entry in page.entries + (page.local.map { [$0] } ?? []) {
                        var row = combined[entry.player.id] ?? WalkingFriend(id: entry.player.id,
                            name: entry.player.name, isMe: entry.player.id == player.id)
                        if board == .month {
                            row.month = entry.context == monthContext ? max(0, entry.score) : nil
                        } else { row.total = max(0, entry.score) }
                        combined[row.id] = row
                    }
                    // Empty pages can happen when a friendship changes during the request.
                    if page.ranksRead == 0 || start + page.ranksRead > page.total { break }
                    start += page.ranksRead
                } while active(operation, playerID: player.id)
            }
            guard active(operation, playerID: player.id) else { return }
            rows = combined.values.sorted {
                let a = monthlyEnabled ? ($0.month ?? -1) : ($0.total ?? -1)
                let b = monthlyEnabled ? ($1.month ?? -1) : ($1.total ?? -1)
                if a != b { return a > b }
                return $0.name.localizedStandardCompare($1.name) == .orderedAscending
            }
            status = .ready
        } catch {
            if active(operation) { status = backend.account == nil ? .signIn : .failed }
        }
    }

    func photo(playerID: String) async -> UIImage? {
        guard isSharing, account?.id == consentAccountID else { return nil }
        let operation = generation
        let photo = await backend.photo(playerID: playerID)
        return active(operation) ? photo : nil
    }

    private func enabled(_ board: HatchLeaderboard) -> Bool { board == .month ? monthlyEnabled : totalEnabled }
    private func active(_ operation: Int, playerID: String? = nil) -> Bool {
        guard generation == operation, isSharing else { return false }
        if let consentAccountID, backend.account?.id != consentAccountID {
            stopForAccountChange(); return false
        }
        return (playerID == nil || backend.account?.id == playerID) &&
        (playerID == nil || consentAccountID == playerID)
    }
    private func authenticationDidChange() {
        account = backend.account
        if let consentAccountID, backend.account?.id != consentAccountID { stopForAccountChange() }
    }
    private func stopForAccountChange() {
        generation += 1
        monthlyEnabled = false; totalEnabled = false; consentAccountID = nil
        rows.removeAll(); sent.removeAll(); backend.discardCachedFriends(); persistConsent()
        status = backend.account == nil ? .signIn : .off
    }
    private func persistConsent() {
        guard DemoMode.scenario != "phone-friends" else { return }
        defaults.set(monthlyEnabled, forKey: Self.monthlyKey)
        defaults.set(totalEnabled, forKey: Self.totalKey)
        defaults.set(consentAccountID, forKey: Self.accountKey)
    }
}
