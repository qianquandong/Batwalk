import Foundation

/// The iPhone requests a preference change; the Watch alone writes it.
/// `birthday == nil` explicitly removes the saved month/day.
public struct PlayerSettingsRequest: Codable, Equatable, Sendable {
    public let id: UUID
    public let saveID: UUID
    public let baseRevision: UInt64
    public let requestedAt: Date
    public let birthday: MonthDay?
    public var expiresAt: Date { requestedAt.addingTimeInterval(Tuning.settingsRequestLifetime) }

    public init(id: UUID = UUID(), saveID: UUID, baseRevision: UInt64,
                requestedAt: Date = Date(), birthday: MonthDay?) {
        self.id = id; self.saveID = saveID; self.baseRevision = baseRevision
        self.requestedAt = requestedAt; self.birthday = birthday
    }
}

public enum PlayerSettingsOutcome: String, Codable, Sendable {
    case applied, expired, saveChanged, superseded, saveFailed
}

public struct PlayerSettingsReceipt: Codable, Equatable, Sendable {
    public let request: PlayerSettingsRequest
    public let outcome: PlayerSettingsOutcome
    public let revision: UInt64

    public init(request: PlayerSettingsRequest, outcome: PlayerSettingsOutcome, revision: UInt64) {
        self.request = request; self.outcome = outcome; self.revision = revision
    }
}

/// The phone waits for both the receipt and matching mirrored preference, in either order.
public struct PlayerSettingsHandoff: Codable, Equatable, Sendable {
    public private(set) var request: PlayerSettingsRequest?
    public private(set) var receipt: PlayerSettingsReceipt?
    public private(set) var failure: PlayerSettingsOutcome?
    public var isWaiting: Bool { request != nil && failure == nil }
    public init() {}

    @discardableResult
    public mutating func begin(_ request: PlayerSettingsRequest) -> Bool {
        guard !isWaiting else { return false }
        self.request = request; receipt = nil; failure = nil
        return true
    }
    public mutating func receive(_ receipt: PlayerSettingsReceipt, state: GameState, now: Date = Date()) {
        guard receipt.request == request, failure == nil else { return }
        self.receipt = receipt
        if receipt.outcome != .applied { failure = receipt.outcome }
        reconcile(with: state, now: now)
    }
    public mutating func reconcile(with state: GameState, now: Date = Date()) {
        guard let request, failure == nil else { return }
        guard state.saveID == request.saveID else { failure = .saveChanged; return }
        if let receipt, receipt.outcome == .applied, state.revision >= receipt.revision {
            if state.birthday == request.birthday { self = PlayerSettingsHandoff() }
            else { failure = .superseded }
        } else if now >= request.expiresAt { failure = .expired }
    }
}
