import Foundation

/// Explicit cloud allowlist. Never add HealthKit dates/totals, the step ledger,
/// lifetime steps, banked steps or exact egg-step progress to this type.
public struct CollectionBackup: Codable, Equatable, Sendable {
    public let version: Int
    public let saveID: UUID
    public let revision: UInt64
    public let hasStarted: Bool
    public let collection: [String: OwnedBat]
    public let companionID: String?
    public let history: [HatchRecord]
    public let fruit: Int

    public init(state: GameState) {
        version = 1
        saveID = state.saveID
        revision = state.revision
        hasStarted = state.hasStarted
        collection = state.collection
        companionID = state.companionID
        history = state.history
        fruit = state.fruit
    }
}
