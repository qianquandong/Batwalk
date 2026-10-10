import Foundation

/// Presentation-only events. They never change a save, grant EXP or spend fruit.
public enum BatAnimationEvent: String, CaseIterable, Sendable {
    case pet, feed, fly, walkReturn, newDay, signature
}

public struct BatAnimationRequest: Hashable, Sendable {
    public let id: UUID
    public let events: [BatAnimationEvent]

    public init(_ events: [BatAnimationEvent], id: UUID = UUID()) {
        self.id = id
        self.events = events
    }
}

public struct BatAnimationFrame: Hashable, Sendable {
    public let assetName: String
    public let seconds: Double
    /// Fraction of the character canvas; only Walker's travel uses an offset.
    public let offsetX: Double
}

public struct BatAnimationClip: Hashable, Sendable {
    public let speciesID: String
    public let actionID: String
    public let frames: [BatAnimationFrame]
    /// Rest after an ambient cycle; one-shot reactions do not use this value.
    public let restSeconds: Double
}

/// Only clips with shipped frames belong here. The 102-action design catalog
/// remains separate so an unlocked idea is never mistaken for playable art.
public enum PilotAnimationCatalog {
    public static let speciesIDs = ["mochi", "sticky", "walker"]

    public static func universal(for speciesID: String, action: UniversalAction) -> BatAnimationClip? {
        guard speciesIDs.contains(speciesID) else { return nil }
        let durations: [Double]
        let rest: Double
        switch action {
        case .idle: durations = [2.4, 0.18, 0.18, 0.24]; rest = 4
        case .sleep: durations = [1.4, 0.4, 0.4, 0.6]; rest = 3.6
        case .fly: durations = [0.20, 0.20, 0.20, 0.20]; rest = 0
        case .pet: durations = [0.25, 0.40, 0.55, 0.45]; rest = 0
        case .eat: durations = [0.40, 0.45, 0.55, 0.60]; rest = 0
        }
        return clip(speciesID, action.rawValue, indices: [0, 1, 2, 3], durations: durations, rest: rest)
    }

    public static func signatureAction(for speciesID: String) -> BatAction? {
        guard speciesIDs.contains(speciesID) else { return nil }
        return ActionCatalog.actions(for: speciesID).first { $0.tier == .signature }
    }

    public static func signature(for speciesID: String, friendshipLevel: Int) -> BatAnimationClip? {
        guard let action = signatureAction(for: speciesID), friendshipLevel >= action.unlockLevel else { return nil }
        if speciesID == "walker" {
            return clip(speciesID, action.id, indices: Array(repeating: [0, 1, 2, 3], count: 3).flatMap { $0 } + [4, 5],
                        durations: Array(repeating: 0.16, count: 12) + [0.45, 0.9])
        }
        return clip(speciesID, action.id, indices: [0, 1, 2, 3],
                    durations: speciesID == "mochi" ? [0.25, 0.24, 0.24, 1.2] : [0.45, 0.55, 0.55, 0.8])
    }

    public static func reaction(for speciesID: String, event: BatAnimationEvent,
                                friendshipLevel: Int) -> BatAnimationClip? {
        switch event {
        case .pet: return universal(for: speciesID, action: .pet)
        case .feed: return universal(for: speciesID, action: .eat)
        case .fly: return universal(for: speciesID, action: .fly)
        case .signature: return signature(for: speciesID, friendshipLevel: friendshipLevel)
        case .walkReturn:
            if signatureAction(for: speciesID)?.trigger == .walkReturn,
               let special = signature(for: speciesID, friendshipLevel: friendshipLevel) { return special }
            return universal(for: speciesID, action: .fly)
        case .newDay:
            guard signatureAction(for: speciesID)?.trigger == .newDay else { return nil }
            return signature(for: speciesID, friendshipLevel: friendshipLevel)
        }
    }

    public static func ambient(for speciesID: String, mood: BatMood) -> BatAnimationClip? {
        universal(for: speciesID, action: mood == .sleeping || mood == .drowsy ? .sleep : .idle)
    }

    public static func still(for speciesID: String, mood: BatMood) -> String? {
        let action: UniversalAction
        switch mood {
        case .sleeping, .drowsy: action = .sleep
        case .awake: action = .idle
        case .happy: action = .pet
        case .eating: action = .eat
        case .playing: action = .fly
        }
        return universal(for: speciesID, action: action)?.frames.first?.assetName
    }

    private static func clip(_ speciesID: String, _ actionID: String, indices: [Int],
                             durations: [Double], rest: Double = 0) -> BatAnimationClip {
        BatAnimationClip(speciesID: speciesID, actionID: actionID,
            frames: zip(indices, durations).enumerated().map { position, pair in
                let offset = actionID == "power-walk" ? -0.12 + Double(min(position, 11)) * 0.24 / 11 : 0
                return BatAnimationFrame(assetName: "pilot_bat_\(speciesID)_\(actionID)_\(pair.0)",
                                         seconds: pair.1, offsetX: offset)
            }, restSeconds: rest)
    }
}

/// A request cannot start twice after a pause, mood change or task cancellation.
public struct BatAnimationConsumption: Sendable {
    private var lastID: UUID?
    public init() {}

    public mutating func take(_ request: BatAnimationRequest?, enabled: Bool) -> [BatAnimationEvent] {
        guard let request, request.id != lastID else { return [] }
        lastID = request.id
        return enabled ? request.events : []
    }
}

/// Presentation memory for homecoming triggers. Opening a tab again must not replay
/// a celebration. Call only when the companion is actually visible and active.
public struct BatVisitMemory: Codable, Equatable, Sendable {
    private struct Visit: Codable, Equatable, Sendable { var day: String; var steps: Int }
    private var visits: [String: Visit] = [:]
    public init() {}

    public mutating func visit(speciesID: String, day: String, creditedSteps: Int) -> [BatAnimationEvent] {
        let prior = visits[speciesID]
        visits[speciesID] = Visit(day: day, steps: max(0, creditedSteps))
        var events: [BatAnimationEvent] = []
        if prior?.day != day { events.append(.newDay) }
        // The initial Health backfill is not evidence of a walk since last visit.
        if let prior, creditedSteps > prior.steps { events.append(.walkReturn) }
        return events
    }
}

/// A paused/retained Watch tab is not necessarily removed from the hierarchy.
public enum BatPlaybackPolicy {
    public static func permitsAnimation(pageVisible: Bool, sceneActive: Bool,
                                        luminanceReduced: Bool, reduceMotion: Bool) -> Bool {
        pageVisible && sceneActive && !luminanceReduced && !reduceMotion
    }
}
