import GameKit
import UIKit
import BatwalkCore

@MainActor
final class GameCenterWalkingBackend: WalkingTogetherBackend {
    var authenticationChanged: (() -> Void)?
    private var players: [String: GKPlayer] = [:]
    private var allowedFriends = Set<String>()
    private var authenticationTask: Task<Void, Error>?
    private var authenticationContinuation: CheckedContinuation<Void, Error>?

    var account: WalkingAccount? {
        let local = GKLocalPlayer.local
        guard local.isAuthenticated else { return nil }
        return WalkingAccount(id: local.gamePlayerID, name: local.displayName)
    }

    func authenticate(interactively: Bool) async throws {
        if GKLocalPlayer.local.isAuthenticated { return }
        if let authenticationTask { return try await authenticationTask.value }
        let task = Task { @MainActor in
            try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
                self.authenticationContinuation = continuation
                GKLocalPlayer.local.authenticateHandler = { [weak self] controller, error in
                    Task { @MainActor in
                        guard let self else { return }
                        self.authenticationChanged?()
                        if let controller {
                            guard interactively, let host = Self.presentationHost() else {
                                self.finishAuthentication(.failure(WalkingError.signInRequired)); return
                            }
                            host.present(controller, animated: true)
                        } else if GKLocalPlayer.local.isAuthenticated {
                            self.finishAuthentication(.success(()))
                        } else {
                            self.discardCachedFriends()
                            self.finishAuthentication(.failure(error ?? WalkingError.signInRequired))
                        }
                    }
                }
            }
        }
        authenticationTask = task
        defer { authenticationTask = nil }
        try await task.value
    }

    private func finishAuthentication(_ result: Result<Void, Error>) {
        let continuation = authenticationContinuation
        authenticationContinuation = nil
        continuation?.resume(with: result)
    }

    func friendsAllowed(requestIfNeeded: Bool) async throws -> Bool {
        let local = GKLocalPlayer.local
        guard local.isAuthenticated else { throw WalkingError.signInRequired }
        let status = try await local.loadFriendsAuthorizationStatus()
        switch status {
        case .authorized:
            let friends = try await local.loadFriends()
            allowedFriends = Set(friends.map(\.gamePlayerID))
            players = Dictionary(friends.map { ($0.gamePlayerID, $0) }, uniquingKeysWith: { first, _ in first })
            return true
        case .notDetermined where requestIfNeeded:
            do { _ = try await local.loadFriends() }
            catch {
                let updated = try await local.loadFriendsAuthorizationStatus()
                if updated == .denied || updated == .restricted { discardCachedFriends(); return false }
                throw error
            }
            return try await friendsAllowed(requestIfNeeded: false)
        case .notDetermined, .denied, .restricted:
            discardCachedFriends(); return false
        @unknown default:
            discardCachedFriends(); return false
        }
    }

    func submit(_ score: HatchLeaderboardScore) async throws {
        guard GKLocalPlayer.local.isAuthenticated else { throw WalkingError.signInRequired }
        // Only these two enum values exist. Never submit a context containing steps.
        try await GKLeaderboard.submitScore(score.value, context: score.context,
            player: GKLocalPlayer.local, leaderboardIDs: [score.board.rawValue])
    }

    func friends(board: HatchLeaderboard, start: Int, count: Int) async throws -> WalkingPage {
        guard GKLocalPlayer.local.isAuthenticated else { throw WalkingError.signInRequired }
        guard let leaderboard = try await GKLeaderboard.loadLeaderboards(IDs: [board.rawValue]).first else {
            throw WalkingError.unavailable
        }
        let (local, entries, total) = try await leaderboard.loadEntries(for: .friendsOnly,
            timeScope: .allTime, range: NSRange(location: max(1, start), length: min(100, max(1, count))))
        let visible = entries.filter {
            $0.player.gamePlayerID == account?.id || allowedFriends.contains($0.player.gamePlayerID)
        }
        for entry in visible { players[entry.player.gamePlayerID] = entry.player }
        if let local { players[local.player.gamePlayerID] = local.player }
        return WalkingPage(local: local.map(Self.entry), entries: visible.map(Self.entry),
                           total: total, ranksRead: entries.count)
    }

    func photo(playerID: String) async -> UIImage? {
        guard let player = players[playerID] else { return nil }
        return try? await player.loadPhoto(for: .small)
    }

    func discardCachedFriends() { players.removeAll(); allowedFriends.removeAll() }

    private static func entry(_ value: GKLeaderboard.Entry) -> WalkingEntry {
        WalkingEntry(player: WalkingAccount(id: value.player.gamePlayerID, name: value.player.displayName),
                     score: value.score, context: value.context)
    }

    private static func presentationHost() -> UIViewController? {
        let scenes = UIApplication.shared.connectedScenes.compactMap { $0 as? UIWindowScene }
        var host = scenes.filter { $0.activationState == .foregroundActive }
            .flatMap(\.windows).first(where: \.isKeyWindow)?.rootViewController
        while let presented = host?.presentedViewController { host = presented }
        return host
    }
}

enum WalkingError: Error { case signInRequired, unavailable }

/// Screenshot data never authenticates or sends anything to Game Center.
@MainActor
final class DemoWalkingBackend: WalkingTogetherBackend {
    var account: WalkingAccount? = WalkingAccount(id: "demo-me", name: "You")
    var authenticationChanged: (() -> Void)?
    func authenticate(interactively: Bool) async throws {}
    func friendsAllowed(requestIfNeeded: Bool) async throws -> Bool { true }
    func submit(_ score: HatchLeaderboardScore) async throws {}
    func friends(board: HatchLeaderboard, start: Int, count: Int) async throws -> WalkingPage {
        let context = board == .month ? HatchLeaderboards.monthKey(at: .now) : 0
        let names = [("demo-willow", "Willow", 5, 24), ("demo-me", "You", 3, 16), ("demo-fern", "Fern", 2, 11)]
        let entries = names.map { id, name, month, total in
            WalkingEntry(player: WalkingAccount(id: id, name: name), score: board == .month ? month : total, context: context)
        }
        return WalkingPage(local: entries[1], entries: start == 1 ? entries : [], total: entries.count)
    }
    func photo(playerID: String) async -> UIImage? { nil }
    func discardCachedFriends() {}
}
