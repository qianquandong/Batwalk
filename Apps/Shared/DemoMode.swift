import Foundation
import BatwalkCore

/// Whether step data is flowing from Apple Health (shown in Watch Settings).
enum HealthStatus: Equatable {
    case connected
    case notSetUp
    case needsAttention
}

/// Visual-QA scenarios (UI_REDESIGN_TASKS P11), selected with a launch argument:
///     -BatwalkDemo <scenario>
/// The screenshots workflow captures each one in the Watch / iPhone simulator.
/// A demo state lives only in memory: never saved, synced, or fed by HealthKit.
/// Without the argument this file does nothing.
enum DemoMode {
    // The capture script reads these two lines — keep each list on one line.
    static let watchScenarios = ["first-egg", "home", "home-day", "hatch-ready", "reveal-rare", "progress-61", "progress-100", "friendship-1", "fruit-available", "friendship-5", "collection-1", "collection-rare", "settings", "health-error"] // scenarios:watch
    static let phoneScenarios = ["phone-batpedia", "phone-batpedia-rare", "phone-detail", "phone-history", "phone-unlock", "phone-stats", "phone-empty"] // scenarios:phone

    static let scenario: String? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-BatwalkDemo"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }()

    static var isActive: Bool { scenario != nil }

    /// Forced Day / Dusk / Night (nil = real clock).
    private(set) static var timeOverride: TimeOfDay?
    /// Watch: 0 Home · 1 Progress · 2 Friendship · 3 Bats · 4 Settings.
    /// iPhone: 0 Batpedia · 1 History · 2 Stats · 3 Unlock.
    private(set) static var page = 0
    /// Hatch result shown as the reveal on launch.
    private(set) static var reveal: HatchResult?
    /// iPhone: open this bat's detail page.
    private(set) static var detailSpecies: String?
    private(set) static var healthStatus: HealthStatus?
    /// Bats to play the unlock reveal on in the collection.
    private(set) static var newlyUnlocked: Set<String> = []

    static func timeOfDay(at date: Date) -> TimeOfDay {
        timeOverride ?? TimeOfDay.at(date)
    }

    /// Builds the in-memory game state for the current scenario.
    static func makeState() -> GameState? {
        guard let scenario else { return nil }
        let now = Date()
        let day = DayKey.make(now)
        var state = GameState()
        var total = 0
        timeOverride = .night

        func walk(_ steps: Int) {
            total += steps
            state.ingestSteps(dayKey: day, dailyTotal: total)
        }
        @discardableResult
        func hatch(_ egg: EggType, _ species: String, shiny: Bool = false) -> HatchResult? {
            guard (try? state.startEgg(egg, seed: seed(egg, species, shiny: shiny), now: now)) != nil else { return nil }
            walk(egg.targetSteps)
            return try? state.hatch(now: now)
        }
        /// Board numbers: Tiny egg at 61 %, "961 steps to hatch", Today 3,539.
        func boardEgg() {
            try? state.startEgg(.tiny, seed: 7, now: now)
            walk(1_539)
        }
        func addCollection() {
            hatch(.forest, "strawberry")
            hatch(.moon, "moonwing")
            hatch(.moon, "galaxy")
            hatch(.tiny, "cocoa")
        }

        state.setUnlocked(true)
        state.start(seed: 1, now: now)

        if scenario == "first-egg" {
            walk(1_230)
            return state
        }
        if scenario == "phone-empty" {
            return GameState()
        }

        walk(2_000)
        _ = try? state.hatch(now: now) // Mochi, the starter

        switch scenario {
        case "home-day":
            timeOverride = .day
            boardEgg()
        case "hatch-ready":
            try? state.startEgg(.tiny, seed: 7, now: now)
            walk(2_500)
        case "reveal-rare":
            reveal = hatch(.moon, "moonwing")
            boardEgg()
        case "progress-61":
            page = 1
            boardEgg()
        case "progress-100":
            page = 1
            try? state.startEgg(.tiny, seed: 7, now: now)
            walk(2_500)
        case "friendship-1":
            // Board: Lv. 1 · 20 / 100 · Feed (0)
            page = 2
            boardEgg()
            _ = try? state.feed("mochi")
            _ = try? state.feed("mochi")
        case "fruit-available":
            page = 2
            boardEgg()
        case "friendship-5":
            page = 2
            for _ in 0..<26 { hatch(.tiny, "mochi") } // duplicates → Friendship EXP
            boardEgg()
        case "collection-1":
            page = 3
            boardEgg()
        case "collection-rare":
            page = 3
            addCollection()
            newlyUnlocked = ["galaxy"]
            boardEgg()
        case "settings":
            page = 4
            healthStatus = .connected
            boardEgg()
        case "health-error":
            page = 4
            healthStatus = .needsAttention
            boardEgg()
        case "phone-batpedia":
            page = 0
            boardEgg()
        case "phone-batpedia-rare":
            page = 0
            addCollection()
            boardEgg()
        case "phone-detail":
            page = 0
            detailSpecies = "mochi"
            boardEgg()
        case "phone-history":
            page = 1
            boardEgg()
        case "phone-unlock":
            page = 3
            state.setUnlocked(false)
            boardEgg()
        case "phone-stats":
            page = 2
            boardEgg()
        default: // "home"
            boardEgg()
        }
        return state
    }

    /// First seed whose roll yields `species` (deterministic, so screenshots are stable).
    private static func seed(_ egg: EggType, _ species: String, shiny: Bool) -> UInt64 {
        var s: UInt64 = 1
        while s < 3_000_000 {
            let roll = HatchEngine.roll(egg: egg, seed: s, isUnlocked: true)
            if roll.species.id == species && roll.isShiny == shiny { return s }
            s += 1
        }
        return 1
    }
}
