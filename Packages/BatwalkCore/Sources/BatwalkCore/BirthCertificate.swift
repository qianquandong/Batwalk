import Foundation

public extension HatchRecord {
    var certificateEggName: String { eggTierName ?? eggType.displayName(forTargetSteps: eggSteps) }

    /// No inferred history: legacy records and Moon Dust arrivals have no walk receipt.
    func certificateDays(calendar: Calendar = .current) -> Int? {
        guard source == .egg, let eggStartedAt, eggSteps != nil, eggStartedAt <= hatchedAt else { return nil }
        let start = calendar.startOfDay(for: eggStartedAt)
        let end = calendar.startOfDay(for: hatchedAt)
        return max(1, calendar.dateComponents([.day], from: start, to: end).day ?? 0)
    }

    var withoutActivityMetrics: HatchRecord {
        var copy = self
        copy.eggStartedAt = nil
        copy.eggSteps = nil
        return copy
    }
}

/// Sent only after the player taps “Include my steps and days” on a certificate.
/// No background queue: both apps must be reachable, and the response stays in memory.
public struct CertificateMetricsRequest: Codable, Equatable, Sendable {
    public let saveID: UUID
    public let recordIndex: Int
    public let speciesID: String
    public let hatchedAt: Date

    public init(saveID: UUID, recordIndex: Int, speciesID: String, hatchedAt: Date) {
        self.saveID = saveID; self.recordIndex = recordIndex
        self.speciesID = speciesID; self.hatchedAt = hatchedAt
    }

    public func metrics(in state: GameState) -> CertificateMetrics? {
        guard state.saveID == saveID, state.history.indices.contains(recordIndex) else { return nil }
        let record = state.history[recordIndex]
        guard record.speciesID == speciesID, record.hatchedAt == hatchedAt,
              record.source == .egg, let start = record.eggStartedAt, let steps = record.eggSteps,
              steps > 0, start <= record.hatchedAt else { return nil }
        return CertificateMetrics(eggStartedAt: start, eggSteps: steps)
    }
}

public struct CertificateMetrics: Codable, Equatable, Sendable {
    public let eggStartedAt: Date
    public let eggSteps: Int
    public init(eggStartedAt: Date, eggSteps: Int) {
        self.eggStartedAt = eggStartedAt; self.eggSteps = eggSteps
    }
    public func applying(to record: HatchRecord) -> HatchRecord {
        var copy = record
        copy.eggStartedAt = eggStartedAt
        copy.eggSteps = eggSteps
        return copy
    }
}
