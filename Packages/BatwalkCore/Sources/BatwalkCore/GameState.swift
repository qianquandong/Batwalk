import Foundation

/// One species in the player's collection. Duplicates never create a second
/// entry — they become Friendship EXP (PRD §2.7).
public struct OwnedBat: Codable, Equatable, Identifiable, Sendable {
    public var id: String { speciesID }
    public let speciesID: String
    /// Player-given name shown on the Watch home (PRD §6.2). nil → species name.
    public var nickname: String?
    public var hasNormal: Bool
    public var hasShiny: Bool
    /// Which variant to display when both are owned.
    public var showsShiny: Bool
    public var friendshipEXP: Int
    public var hatchCount: Int
    public let firstHatchedAt: Date

    public var species: Species? { Roster.species(speciesID) }
    public var displayName: String { nickname ?? species?.name ?? speciesID }
}

/// The egg currently incubating.
public struct ActiveEgg: Codable, Equatable, Sendable {
    public let type: EggType
    /// Fixed at creation → the hatch outcome cannot be rerolled.
    public let seed: UInt64
    public var creditedSteps: Int
    public let startedAt: Date
    public var frozenSpeciesID: String? = nil
    public var frozenIsShiny: Bool? = nil

    public var progress: Double { min(1, Double(creditedSteps) / Double(type.targetSteps)) }
    public var isReady: Bool { creditedSteps >= type.targetSteps }
    public var stepsRemaining: Int { max(0, type.targetSteps - creditedSteps) }
    public var visualState: EggVisualState { .forProgress(progress) }
}

public struct HatchRecord: Codable, Equatable, Sendable {
    public let speciesID: String
    public let isShiny: Bool
    public let eggType: EggType
    public let hatchedAt: Date
    public let outcome: HatchOutcome
}

public enum HatchOutcome: String, Codable, Sendable {
    /// First time this species was hatched.
    case newSpecies
    /// Species owned, but this is its first Shiny.
    case newShiny
    /// Already owned in this variant → Friendship EXP.
    case duplicate
}

public struct HatchResult: Equatable, Sendable {
    public let record: HatchRecord
    public let friendshipGained: Int
    public let bat: OwnedBat
}

/// What happened when new steps were ingested — drives haptics and notifications.
public struct StepUpdate: Equatable, Sendable {
    public var creditedSteps = 0
    public var eggBecameReady = false
    public var fruitEarned = 0

    public init() {}
}

public enum GameError: Error, Equatable, Sendable {
    case noEgg
    case eggNotReady
    case eggAlreadyIncubating
    case eggLocked(EggType)
    case notOwned(String)
    case noFruit
}

/// The whole save file. A value type with pure, deterministic mutations so every
/// rule is unit-tested; the apps only persist it and render it.
public struct GameState: Codable, Equatable, Sendable {
    public static let currentSchemaVersion = 2

    public var schemaVersion = GameState.currentSchemaVersion
    public private(set) var saveID = UUID()
    public private(set) var revision: UInt64 = 0
    public private(set) var needsStepBaseline = false
    public private(set) var hasStarted = false
    public private(set) var egg: ActiveEgg?
    /// Steps earned while no egg was incubating, applied to the next egg.
    public private(set) var bankedSteps = 0
    public private(set) var ledger = StepLedger()
    public private(set) var collection: [String: OwnedBat] = [:]
    public private(set) var companionID: String?
    public private(set) var fruit = 0
    public private(set) var fruitProgressSteps = 0
    public private(set) var isUnlocked = false
    public private(set) var history: [HatchRecord] = []
    /// speciesID → (dayKey, pets that granted EXP that day)
    public private(set) var petLog: [String: PetDay] = [:]
    public private(set) var lifetimeCreditedSteps = 0

    public struct PetDay: Codable, Equatable, Sendable {
        public var dayKey: String
        public var count: Int
    }

    public init() {}

    private enum CodingKeys: String, CodingKey {
        case schemaVersion, saveID, revision, needsStepBaseline, hasStarted, egg, bankedSteps
        case ledger, collection, companionID, fruit, fruitProgressSteps, isUnlocked, history, petLog, lifetimeCreditedSteps
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let version = try c.decodeIfPresent(Int.self, forKey: .schemaVersion) ?? 1
        guard version <= Self.currentSchemaVersion else {
            throw DecodingError.dataCorruptedError(forKey: .schemaVersion, in: c, debugDescription: "This save needs a newer Batwalk version.")
        }
        schemaVersion = Self.currentSchemaVersion
        saveID = try c.decodeIfPresent(UUID.self, forKey: .saveID) ?? UUID()
        revision = try c.decodeIfPresent(UInt64.self, forKey: .revision) ?? 0
        needsStepBaseline = try c.decodeIfPresent(Bool.self, forKey: .needsStepBaseline) ?? false
        hasStarted = try c.decodeIfPresent(Bool.self, forKey: .hasStarted) ?? false
        egg = try c.decodeIfPresent(ActiveEgg.self, forKey: .egg)
        bankedSteps = try c.decodeIfPresent(Int.self, forKey: .bankedSteps) ?? 0
        ledger = try c.decodeIfPresent(StepLedger.self, forKey: .ledger) ?? StepLedger()
        collection = try c.decodeIfPresent([String: OwnedBat].self, forKey: .collection) ?? [:]
        companionID = try c.decodeIfPresent(String.self, forKey: .companionID)
        fruit = try c.decodeIfPresent(Int.self, forKey: .fruit) ?? 0
        fruitProgressSteps = try c.decodeIfPresent(Int.self, forKey: .fruitProgressSteps) ?? 0
        isUnlocked = try c.decodeIfPresent(Bool.self, forKey: .isUnlocked) ?? false
        history = try c.decodeIfPresent([HatchRecord].self, forKey: .history) ?? []
        petLog = try c.decodeIfPresent([String: PetDay].self, forKey: .petLog) ?? [:]
        lifetimeCreditedSteps = try c.decodeIfPresent(Int.self, forKey: .lifetimeCreditedSteps) ?? 0
        // v1 eggs are sealed once during migration, before any entitlement refresh.
        if var current = egg, current.frozenSpeciesID == nil {
            let roll = HatchEngine.roll(egg: current.type, seed: current.seed, isUnlocked: isUnlocked || !current.type.isFree)
            current.frozenSpeciesID = roll.species.id
            current.frozenIsShiny = roll.isShiny
            egg = current
        }
    }

    public mutating func advanceRevision() { revision += 1 }

    public mutating func beginStepTracking(on day: String, timeZone: String) {
        ledger.beginTracking(on: day, timeZone: timeZone)
    }

    public mutating func establishStepBaseline(day: String, total: Int, timeZone: String) {
        ledger.establishBaseline(dayKey: day, total: total, timeZone: timeZone)
        needsStepBaseline = false
    }

    // MARK: - Derived

    public var companion: OwnedBat? { companionID.flatMap { collection[$0] } }
    public var isEggReady: Bool { egg?.isReady ?? false }
    public var pickableEggs: [EggType] { EggType.pickable(isUnlocked: isUnlocked) }

    /// Used to pick between two saves after an iCloud restore races a fresh
    /// install: the save with more hatches wins, then more lifetime steps.
    public func isRicher(than other: GameState) -> Bool {
        if saveID == other.saveID { return revision > other.revision }
        if history.count != other.history.count { return history.count > other.history.count }
        return lifetimeCreditedSteps > other.lifetimeCreditedSteps
    }

    /// Collection grid in Batpedia order.
    public var sortedCollection: [OwnedBat] {
        collection.values.sorted { ($0.species?.number ?? 0) < ($1.species?.number ?? 0) }
    }

    // MARK: - Onboarding

    /// PRD §2.2: the first egg is always a Starter Egg.
    public mutating func start(seed: UInt64, now: Date) {
        guard !hasStarted else { return }
        hasStarted = true
        egg = ActiveEgg(type: .starter, seed: seed, creditedSteps: 0, startedAt: now)
        freezeEgg(tuning: .default)
    }

    private mutating func freezeEgg(tuning: Tuning) {
        guard var current = egg else { return }
        let roll = HatchEngine.roll(egg: current.type, seed: current.seed, isUnlocked: isUnlocked, tuning: tuning)
        current.frozenSpeciesID = roll.species.id
        current.frozenIsShiny = roll.isShiny
        egg = current
    }

    // MARK: - Steps

    /// Ingest HealthKit's cumulative total for a day. See `StepLedger`.
    @discardableResult
    public mutating func ingestSteps(dayKey: String, dailyTotal: Int, tuning: Tuning = .default) -> StepUpdate {
        let delta = ledger.ingest(dayKey: dayKey, dailyTotal: dailyTotal)
        return credit(steps: delta, tuning: tuning)
    }

    @discardableResult
    mutating func credit(steps: Int, tuning: Tuning = .default) -> StepUpdate {
        var update = StepUpdate()
        guard steps > 0 else { return update }
        update.creditedSteps = steps
        lifetimeCreditedSteps += steps

        var remaining = steps
        if var current = egg, !current.isReady {
            let applied = min(remaining, current.stepsRemaining)
            current.creditedSteps += applied
            remaining -= applied
            update.eggBecameReady = current.isReady
            egg = current
        }
        if remaining > 0 {
            bankedSteps = min(tuning.maxBankedSteps, bankedSteps + remaining)
        }

        // Fruit (PRD §2.8): occasional reward from walking, no hunger system.
        fruitProgressSteps += steps
        while fruitProgressSteps >= tuning.stepsPerFruit {
            fruitProgressSteps -= tuning.stepsPerFruit
            if fruit < tuning.maxFruit {
                fruit += 1
                update.fruitEarned += 1
            }
        }
        return update
    }

    // MARK: - Hatching

    /// Tap-to-reveal on the Watch. Clears the egg; the player then picks the next one.
    public mutating func hatch(now: Date, tuning: Tuning = .default) throws -> HatchResult {
        guard let current = egg else { throw GameError.noEgg }
        guard current.isReady else { throw GameError.eggNotReady }

        // An egg started under the full unlock keeps its paid pool even if the
        // entitlement later reads as false (refund, restore not yet run).
        let paidPool = isUnlocked || !current.type.isFree
        let roll: HatchRoll
        if let id = current.frozenSpeciesID, let species = Roster.species(id), let shiny = current.frozenIsShiny {
            roll = HatchRoll(species: species, isShiny: shiny)
        } else {
            roll = HatchEngine.roll(egg: current.type, seed: current.seed, isUnlocked: paidPool, tuning: tuning)
        }
        let id = roll.species.id

        let outcome: HatchOutcome
        var gained = 0
        var bat: OwnedBat
        if var existing = collection[id] {
            if roll.isShiny && !existing.hasShiny {
                outcome = .newShiny
                existing.hasShiny = true
                existing.showsShiny = true
            } else if !roll.isShiny && !existing.hasNormal {
                outcome = .newSpecies
                existing.hasNormal = true
            } else {
                outcome = .duplicate
                gained = tuning.duplicateEXP[roll.species.rarity] ?? 0
                existing.friendshipEXP += gained
            }
            existing.hatchCount += 1
            bat = existing
        } else {
            outcome = .newSpecies
            bat = OwnedBat(
                speciesID: id,
                nickname: nil,
                hasNormal: !roll.isShiny,
                hasShiny: roll.isShiny,
                showsShiny: roll.isShiny,
                friendshipEXP: 0,
                hatchCount: 1,
                firstHatchedAt: now
            )
        }
        collection[id] = bat

        // First bat becomes the companion (PRD §2.2 step 10).
        if companionID == nil { companionID = id }

        let record = HatchRecord(speciesID: id, isShiny: roll.isShiny, eggType: current.type,
                                 hatchedAt: now, outcome: outcome)
        history.append(record)
        egg = nil
        return HatchResult(record: record, friendshipGained: gained, bat: bat)
    }

    /// Start the next egg. Banked steps are applied immediately.
    @discardableResult
    public mutating func startEgg(_ type: EggType, seed: UInt64, now: Date, tuning: Tuning = .default) throws -> StepUpdate {
        guard egg == nil else { throw GameError.eggAlreadyIncubating }
        guard type.isPickable, isUnlocked || type.isFree else { throw GameError.eggLocked(type) }
        egg = ActiveEgg(type: type, seed: seed, creditedSteps: 0, startedAt: now)
        freezeEgg(tuning: tuning)

        let banked = bankedSteps
        bankedSteps = 0
        var update = StepUpdate()
        if var current = egg, banked > 0 {
            let applied = min(banked, current.type.targetSteps)
            current.creditedSteps = applied
            egg = current
            bankedSteps = banked - applied
            update.creditedSteps = applied
            update.eggBecameReady = current.isReady
        }
        return update
    }

    // MARK: - Care (PRD §2.8 — no punishment, ever)

    public mutating func setCompanion(_ speciesID: String) throws {
        guard collection[speciesID] != nil else { throw GameError.notOwned(speciesID) }
        companionID = speciesID
    }

    /// Empty / whitespace-only name resets to the species name.
    public mutating func rename(_ speciesID: String, to name: String, tuning: Tuning = .default) throws {
        guard var bat = collection[speciesID] else { throw GameError.notOwned(speciesID) }
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        bat.nickname = trimmed.isEmpty ? nil : String(trimmed.prefix(tuning.maxNicknameLength))
        collection[speciesID] = bat
    }

    public mutating func setShowsShiny(_ speciesID: String, _ showsShiny: Bool) throws {
        guard var bat = collection[speciesID] else { throw GameError.notOwned(speciesID) }
        bat.showsShiny = bat.hasShiny && (showsShiny || !bat.hasNormal)
        collection[speciesID] = bat
    }

    /// Returns the EXP gained.
    @discardableResult
    public mutating func feed(_ speciesID: String, tuning: Tuning = .default) throws -> Int {
        guard var bat = collection[speciesID] else { throw GameError.notOwned(speciesID) }
        guard fruit > 0 else { throw GameError.noFruit }
        fruit -= 1
        bat.friendshipEXP += tuning.feedEXP
        collection[speciesID] = bat
        return tuning.feedEXP
    }

    /// Petting always plays a reaction; only the first `petEXPDailyCap` pets per day give EXP.
    @discardableResult
    public mutating func pet(_ speciesID: String, dayKey: String, tuning: Tuning = .default) throws -> Int {
        guard var bat = collection[speciesID] else { throw GameError.notOwned(speciesID) }
        var log = petLog[speciesID] ?? PetDay(dayKey: dayKey, count: 0)
        if log.dayKey != dayKey { log = PetDay(dayKey: dayKey, count: 0) }
        guard log.count < tuning.petEXPDailyCap else { return 0 }
        log.count += 1
        petLog[speciesID] = log
        bat.friendshipEXP += tuning.petEXP
        collection[speciesID] = bat
        return tuning.petEXP
    }

    // MARK: - Purchase

    /// $1.99 one-time unlock (or Restore Purchase). Idempotent.
    public mutating func setUnlocked(_ unlocked: Bool) {
        isUnlocked = unlocked
    }

    public mutating func restoreCollection(_ backup: CollectionBackup) {
        saveID = backup.saveID
        revision = backup.revision
        hasStarted = backup.hasStarted
        collection = backup.collection
        companionID = backup.companionID.flatMap { collection[$0] == nil ? nil : $0 }
        history = backup.history
        fruit = backup.fruit
        egg = nil
        bankedSteps = 0
        ledger = StepLedger()
        petLog = [:]
        fruitProgressSteps = 0
        lifetimeCreditedSteps = 0
        needsStepBaseline = true
        // StoreKit, rather than a backup, remains the authority for purchases.
    }
}
