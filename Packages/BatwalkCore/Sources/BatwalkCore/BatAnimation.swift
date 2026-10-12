import Foundation

/// Presentation-only events. They never change a save, grant EXP or spend fruit.
public enum BatAnimationEvent: String, CaseIterable, Sendable {
    case pet, feed, fly, walkReturn, newDay, signature, hatch
}

public struct BatAnimationRequest: Hashable, Sendable {
    public let id: UUID
    public let events: [BatAnimationEvent]
    public let actionIDs: [String]

    public init(_ events: [BatAnimationEvent] = [], actionIDs: [String] = [], id: UUID = UUID()) {
        self.id = id
        self.events = events
        self.actionIDs = actionIDs
    }

    /// Celebrate every crossed level, including jumps, without changing game state.
    public static func interaction(_ event: BatAnimationEvent, speciesID: String,
                                   levelBefore: Int, levelAfter: Int) -> Self {
        let unlocked = ActionCatalog.actions(for: speciesID).filter {
            $0.unlockLevel > levelBefore && $0.unlockLevel <= levelAfter
        }
        return Self([event], actionIDs: unlocked.map(\.id))
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

/// Frame plan of the generated Gentle-pixel sets (Art/tools/gentle_pixel): how
/// many frames each universal action has, how long each shows, and the rest on
/// frame 0 after an ambient cycle. Mirrors `PLAN` in engine.js exactly — change
/// both together, then re-export.
public enum GeneratedFramePlan {
    public struct Plan: Sendable, Equatable {
        public let seconds: [Double]
        public let rest: Double
        public var count: Int { seconds.count }
        public init(seconds: [Double], rest: Double) { self.seconds = seconds; self.rest = rest }
    }

    public static func plan(for action: UniversalAction) -> Plan {
        switch action {
        case .idle: return Plan(seconds: [0.6, 0.14, 0.14, 0.14, 0.14, 0.14, 0.14, 0.2], rest: 1.6)
        case .sleep: return Plan(seconds: Array(repeating: 0.32, count: 8), rest: 0.8)
        case .fly: return Plan(seconds: Array(repeating: 0.1, count: 6), rest: 0)
        case .pet: return Plan(seconds: Array(repeating: 0.12, count: 8), rest: 0)
        case .eat: return Plan(seconds: [0.18, 0.14, 0.14, 0.22, 0.2, 0.2, 0.22, 0.3], rest: 0)
        }
    }
}

/// Only clips with shipped frames belong here. The 102-action design catalog
/// remains separate so an unlocked idea is never mistaken for playable art.
///
/// The launch 20 have five portrait-derived universal clips plus unique actions.
/// Wave two retains its matching pilots or original portrait fallback.
public enum PilotAnimationCatalog {
    /// Hand-drawn pilots (Art/gentle-pixel/pilots-v1).
    public static let pilotSpeciesIDs = ["mochi", "sticky", "walker"]
    public static let portraitSpeciesIDs: [String] = Roster.catalog.map(\.id).filter { !pilotSpeciesIDs.contains($0) }
    public static var staticFallbackSpeciesIDs: [String] {
        portraitSpeciesIDs.filter { !PortraitUniversalFrames.speciesIDs.contains($0) }
    }
    /// Every species supported by the player, including portrait-only fallback.
    public static var speciesIDs: [String] { pilotSpeciesIDs + portraitSpeciesIDs }

    public static func universal(for speciesID: String, action: UniversalAction) -> BatAnimationClip? {
        if PortraitUniversalFrames.speciesIDs.contains(speciesID) {
            let plan = PortraitUniversalFrames.plan(for: action)
            return clip(speciesID, action.rawValue, indices: Array(plan.seconds.indices),
                        durations: plan.seconds, rest: plan.rest, prefix: "universal_bat_")
        }
        if portraitSpeciesIDs.contains(speciesID) {
            // Never switch to the discarded code-drawn identity between gestures.
            return BatAnimationClip(speciesID: speciesID, actionID: action.rawValue,
                frames: [BatAnimationFrame(assetName: "portrait_bat_\(speciesID)", seconds: 0.4, offsetX: 0)],
                restSeconds: action == .idle || action == .sleep ? 4 : 0)
        }
        guard pilotSpeciesIDs.contains(speciesID) else { return nil }
        let plan = PortraitUniversalFrames.plan(for: action)
        return clip(speciesID, action.rawValue, indices: Array(plan.seconds.indices), durations: plan.seconds, rest: plan.rest)
    }

    /// Only actions with packaged art are exposed, including the launch roster.
    public static func signatureAction(for speciesID: String) -> BatAction? {
        playableActions(for: speciesID).first { $0.tier == .signature }
    }

    public static func signature(for speciesID: String, friendshipLevel: Int) -> BatAnimationClip? {
        guard let action = signatureAction(for: speciesID), friendshipLevel >= action.unlockLevel else { return nil }
        return unique(for: speciesID, actionID: action.id, friendshipLevel: friendshipLevel)
    }

    /// A familiar greeting on opening, chosen deterministically from shipped art.
    /// Feeding/petting reactions and legendary secrets still need their real triggers.
    /// Daytime never wakes a sleeping bat for a flying/night-time performance.
    public static func opening(for speciesID: String, friendshipLevel: Int,
                               time: TimeOfDay) -> BatAnimationClip? {
        let eligible = playableActions(for: speciesID).filter { action in
            guard action.unlockLevel <= friendshipLevel,
                  action.tier == .idleQuirk || action.tier == .signature else { return false }
            switch action.trigger {
            case .asleep: return time == .day
            case .dusk: return time == .dusk
            case .idleNight: return time == .night
            case .walkReturn, .newDay: return time != .day
            default: return false
            }
        }
        let action = eligible.sorted {
            if $0.unlockLevel != $1.unlockLevel { return $0.unlockLevel > $1.unlockLevel }
            return $0.id < $1.id
        }.first
        return action.flatMap { unique(for: speciesID, actionID: $0.id, friendshipLevel: friendshipLevel) }
    }

    public static func playableActions(for speciesID: String) -> [BatAction] {
        ActionCatalog.actions(for: speciesID).filter {
            LaunchActionFrames.seconds["\(speciesID)/\($0.id)"] != nil ||
                (pilotSpeciesIDs.contains(speciesID) && $0.tier == .signature)
        }
    }

    public static func unique(for speciesID: String, actionID: String,
                              friendshipLevel: Int) -> BatAnimationClip? {
        guard let action = playableActions(for: speciesID).first(where: { $0.id == actionID }),
              friendshipLevel >= action.unlockLevel else { return nil }
        if let seconds = LaunchActionFrames.seconds["\(speciesID)/\(actionID)"] {
            return clip(speciesID, actionID, indices: Array(seconds.indices), durations: seconds,
                        prefix: "unique_bat_")
        }
        if speciesID == "walker" {
            return clip(speciesID, action.id, indices: Array(repeating: [0, 1, 2, 3], count: 3).flatMap { $0 } + [4, 5],
                        durations: Array(repeating: 0.16, count: 12) + [0.45, 0.9])
        }
        return clip(speciesID, action.id, indices: [0, 1, 2, 3],
                    durations: speciesID == "mochi" ? [0.25, 0.24, 0.24, 1.2] : [0.45, 0.55, 0.55, 0.8])
    }

    public static func reaction(for speciesID: String, event: BatAnimationEvent,
                                friendshipLevel: Int) -> BatAnimationClip? {
        reactions(for: speciesID, event: event, friendshipLevel: friendshipLevel).first
    }

    public static func reactions(for speciesID: String, event: BatAnimationEvent,
                                 friendshipLevel: Int) -> [BatAnimationClip] {
        if event == .signature { return [signature(for: speciesID, friendshipLevel: friendshipLevel)].compactMap { $0 } }
        let trigger: ActionTrigger?
        switch event {
        case .pet: trigger = .pet
        case .feed: trigger = .feed
        case .walkReturn: trigger = .walkReturn
        case .newDay: trigger = .newDay
        case .hatch: trigger = .hatch
        case .fly, .signature: trigger = nil
        }
        if let trigger {
            let specials = ActionCatalog.available(for: speciesID, friendshipLevel: friendshipLevel, trigger: trigger)
                .compactMap { unique(for: speciesID, actionID: $0.id, friendshipLevel: friendshipLevel) }
            if !specials.isEmpty { return specials }
        }
        let fallback: UniversalAction?
        switch event {
        case .pet: fallback = .pet
        case .feed: fallback = .eat
        case .fly, .walkReturn: fallback = .fly
        default: fallback = nil
        }
        return fallback.flatMap { universal(for: speciesID, action: $0) }.map { [$0] } ?? []
    }

    /// A newly unlocked reaction may also match this interaction. Play it once.
    public static func clips(for request: BatAnimationRequest, speciesID: String,
                             friendshipLevel: Int) -> [BatAnimationClip] {
        var seen = Set<String>()
        let natural = request.events.flatMap { reactions(for: speciesID, event: $0, friendshipLevel: friendshipLevel) }
        let unlocked = request.actionIDs.compactMap { unique(for: speciesID, actionID: $0, friendshipLevel: friendshipLevel) }
        return (natural + unlocked).filter { seen.insert($0.actionID).inserted }
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
                             durations: [Double], rest: Double = 0, prefix: String = "pilot_bat_") -> BatAnimationClip {
        BatAnimationClip(speciesID: speciesID, actionID: actionID,
            frames: zip(indices, durations).enumerated().map { position, pair in
                let offset = actionID == "power-walk" ? -0.12 + Double(min(position, 11)) * 0.24 / 11 : 0
                return BatAnimationFrame(assetName: "\(prefix)\(speciesID)_\(actionID)_\(pair.0)",
                                         seconds: pair.1, offsetX: offset)
            }, restSeconds: rest)
    }
}

/// A request cannot start twice after a pause, mood change or task cancellation.
public struct BatAnimationConsumption: Sendable {
    private var lastID: UUID?
    public init() {}

    public mutating func take(_ request: BatAnimationRequest?, enabled: Bool) -> [BatAnimationEvent] {
        guard consume(request, enabled: enabled) else { return [] }
        return request?.events ?? []
    }

    public mutating func consume(_ request: BatAnimationRequest?, enabled: Bool) -> Bool {
        guard let request, request.id != lastID else { return false }
        lastID = request.id
        return enabled
    }
}

/// Small presentation-only memory, independent of the save/sync schema. Each
/// normal beat plays once per local day/period while this companion is mounted.
/// A legendary secret gets one eligible 1-in-24 roll per minute, once per day.
public struct BatAmbientMemory: Sendable {
    private var day: String?
    private var seen = Set<String>()
    private var rareMinute: Int?
    public init() {}

    public mutating func record(_ clip: BatAnimationClip, time: TimeOfDay, day: String) {
        if self.day != day { self.day = day; seen.removeAll(); rareMinute = nil }
        seen.insert("\(clip.speciesID)/\(time.rawValue)/\(clip.actionID)")
        seen.insert("\(clip.speciesID)/secret/\(clip.actionID)")
    }

    public mutating func next(speciesID: String, friendshipLevel: Int, time: TimeOfDay,
                              day: String, minute: Int, rareRoll: Int) -> BatAnimationClip? {
        if self.day != day { self.day = day; seen.removeAll(); rareMinute = nil }
        let trigger: ActionTrigger = time == .day ? .asleep : time == .dusk ? .dusk : .idleNight
        for action in ActionCatalog.available(for: speciesID, friendshipLevel: friendshipLevel, trigger: trigger) {
            let key = "\(speciesID)/\(time.rawValue)/\(action.id)"
            if !seen.contains(key), let clip = PilotAnimationCatalog.unique(for: speciesID, actionID: action.id,
                                                                           friendshipLevel: friendshipLevel) {
                seen.insert(key)
                return clip
            }
        }
        guard friendshipLevel >= 5, rareMinute != minute else { return nil }
        rareMinute = minute
        // Eclipse's midday secret needs daylight; Galaxy surfs a night storm.
        guard rareRoll == 0, (speciesID == "eclipse" ? time == .day : time == .night) else { return nil }
        for action in ActionCatalog.available(for: speciesID, friendshipLevel: friendshipLevel, trigger: .rare) {
            let key = "\(speciesID)/secret/\(action.id)"
            if !seen.contains(key), let clip = PilotAnimationCatalog.unique(for: speciesID, actionID: action.id,
                                                                           friendshipLevel: friendshipLevel) {
                seen.insert(key)
                return clip
            }
        }
        return nil
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

/// One greeting per bat during a foreground visit. Page changes, step updates and
/// wrist dimming do not reset it. This is presentation state, never a game reward.
public struct BatOpeningMemory: Sendable {
    private var seen = Set<String>()
    public init() {}
    public mutating func leaveApp() { seen.removeAll() }

    public mutating func request(speciesID: String, friendshipLevel: Int, time: TimeOfDay,
                                 motionAllowed: Bool) -> BatAnimationRequest? {
        guard seen.insert(speciesID).inserted, motionAllowed,
              let clip = PilotAnimationCatalog.opening(for: speciesID, friendshipLevel: friendshipLevel, time: time)
        else { return nil }
        return BatAnimationRequest(actionIDs: [clip.actionID])
    }
}
