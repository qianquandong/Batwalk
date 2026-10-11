import Foundation

/// A phone asks; only the Watch applies this change. Old queued requests expire.
public struct CompanionChangeRequest: Codable, Equatable, Sendable {
    public let id: UUID
    public let speciesID: String
    public let saveID: UUID
    public let requestedAt: Date
    public var expiresAt: Date { requestedAt.addingTimeInterval(15 * 60) }

    public init(id: UUID = UUID(), speciesID: String, saveID: UUID, requestedAt: Date = Date()) {
        self.id = id; self.speciesID = speciesID; self.saveID = saveID; self.requestedAt = requestedAt
    }
}

public enum CompanionChangeOutcome: String, Codable, Sendable {
    case applied, expired, saveChanged, notOwned, saveFailed, superseded
}

public struct CompanionChangeReceipt: Codable, Equatable, Sendable {
    public let request: CompanionChangeRequest
    public let outcome: CompanionChangeOutcome
    public let revision: UInt64

    public init(request: CompanionChangeRequest, outcome: CompanionChangeOutcome, revision: UInt64) {
        self.request = request; self.outcome = outcome; self.revision = revision
    }
}

/// The receipt and save can arrive in either order. Both must agree before success.
public struct CompanionHandoff: Codable, Equatable, Sendable {
    public private(set) var request: CompanionChangeRequest?
    public private(set) var receipt: CompanionChangeReceipt?
    public private(set) var failure: CompanionChangeOutcome?
    public var isWaiting: Bool { request != nil && failure == nil }

    public init() {}

    @discardableResult
    public mutating func begin(_ request: CompanionChangeRequest) -> Bool {
        guard !isWaiting else { return false }
        self.request = request; receipt = nil; failure = nil
        return true
    }

    public mutating func receive(_ receipt: CompanionChangeReceipt, state: GameState, now: Date = Date()) {
        guard receipt.request == request, failure == nil else { return }
        self.receipt = receipt
        if receipt.outcome != .applied { failure = receipt.outcome }
        reconcile(with: state, now: now)
    }

    public mutating func reconcile(with state: GameState, now: Date = Date()) {
        guard let request, failure == nil else { return }
        guard state.saveID == request.saveID else { failure = .saveChanged; return }
        if let receipt, receipt.outcome == .applied, state.revision >= receipt.revision {
            if state.companionID == request.speciesID { self = CompanionHandoff() }
            else { failure = .superseded }
        } else if now >= request.expiresAt {
            failure = .expired
        }
    }
}
