import Foundation
import BatwalkCore

/// Whether step data is flowing from Apple Health (shown in Watch Settings).
enum HealthStatus: Equatable {
    case connected
    case notSetUp
    case noData
    /// The latest query failed. Zero steps never implies denied access.
    case needsAttention

    var label: String {
        switch self {
        case .connected: return "Steps received"
        case .notSetUp: return "Not set up"
        case .noData: return "No steps received yet"
        case .needsAttention: return "Update failed"
        }
    }
}

/// Visual-QA scenarios (UI_REDESIGN_TASKS P11), selected with a launch argument:
///     -BatwalkDemo <scenario>
/// The screenshots workflow captures each one in the Watch / iPhone simulator.
/// A demo state lives only in memory: never saved, synced, or fed by HealthKit.
/// Without the argument this file does nothing.
enum DemoMode {
    // The capture script reads these two lines — keep each list on one line.
    static let watchScenarios = ["first-egg", "home", "home-day", "home-cocoa", "home-long-ear", "hatch-ready", "reveal-rare", "progress-61", "progress-100", "friendship-1", "friendship-2", "friendship-3", "friendship-4", "fruit-available", "friendship-5", "settings", "health-error", "home-large-type", "pilot-mochi", "pilot-sticky", "pilot-walker", "pilot-cocoa", "pilot-long-ear", "reveal-large-type", "reveal-shiny", "progress-large-type", "step-setup", "step-no-data", "step-read-error", "step-no-data-large-type", "egg-picker", "outfit-gold"] // scenarios:watch
    static let phoneScenarios = ["phone-companion", "phone-batpedia", "phone-batpedia-rare", "phone-detail", "phone-pending", "phone-confirmed", "phone-stale", "phone-first-egg", "phone-egg-ready", "phone-history", "phone-settings", "phone-stats", "phone-empty", "phone-guide", "phone-certificate", "phone-certificate-shiny", "phone-poster", "phone-recap", "phone-challenge", "phone-challenge-gold"] // scenarios:phone

    static let scenario: String? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-BatwalkDemo"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }()

    static var isActive: Bool { scenario != nil }

    static var stepSetupStatus: StepSetupCoordinator.Status? {
        switch scenario {
        case "step-setup": return .idle
        case "step-no-data", "step-no-data-large-type": return .noSteps
        case "step-read-error": return .readFailed
        default: return nil
        }
    }

    /// Forced Day / Dusk / Night (nil = real clock).
    private(set) static var timeOverride: TimeOfDay?
    /// Watch: 0 Companion · 1 Egg (Options is a sheet on the egg page).
    /// iPhone: 0 Companion · 1 Batpedia · 2 Journal. Purchases live in Settings.
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
        // Store captures must match the shipping roster; visual QA can still
        // explore future waves. This only changes in-memory screenshot fixtures.
        let launchRoster = ProcessInfo.processInfo.arguments.contains("-BatwalkLaunchRoster")
        Roster.enabledWave = launchRoster ? SharedConfig.contentWave : 2
        let now = Date()
        var demoDate = now.addingTimeInterval(-90 * 86_400)
        var day = DayKey.make(demoDate)
        var state = GameState()
        var total = 0
        timeOverride = .night

        func walk(_ steps: Int) {
            var remaining = steps
            while remaining > 0 {
                if total >= Tuning.default.maxDailySteps {
                    demoDate = Calendar.current.date(byAdding: .day, value: 1, to: demoDate)!
                    day = DayKey.make(demoDate)
                    total = 0
                }
                let chunk = min(remaining, Tuning.default.maxDailySteps - total)
                total += chunk
                state.ingestSteps(dayKey: day, dailyTotal: total)
                remaining -= chunk
            }
        }
        @discardableResult
        func hatch(_ egg: EggType, _ species: String, shiny: Bool = false) -> HatchResult? {
            let species = launchRoster ? ["sticky": "cocoa", "walker": "snow"][species] ?? species : species
            let paid = state.isUnlocked || !egg.isFree
            guard (try? state.startEgg(egg, seed: seed(egg, species, shiny: shiny, isUnlocked: paid), now: now)) != nil else { return nil }
            walk(egg.targetSteps)
            return try? state.hatch(now: now)
        }
        /// Keep the visual fixture at 61% when egg pacing changes.
        func boardEgg() {
            try? state.startEgg(.tiny, seed: 7, now: now)
            walk(EggType.tiny.targetSteps * 61 / 100)
        }
        func addCollection() {
            hatch(.forest, "strawberry")
            hatch(.moon, "moonwing")
            hatch(.moon, "galaxy")
            hatch(.tiny, "cocoa")
        }

        state.setUnlocked(true)
        state.start(seed: 1, now: now)

        if stepSetupStatus != nil { return state }

        if scenario == "first-egg" || scenario == "phone-first-egg" {
            walk(1_230)
            return state
        }
        if scenario == "phone-empty" {
            return GameState()
        }

        walk(2_000)
        _ = try? state.hatch(now: now) // Mochi, the starter

        switch scenario {
        case "pilot-mochi", "pilot-sticky", "pilot-walker", "pilot-cocoa", "pilot-long-ear":
            // The three hand-drawn pilots, and two generated Gentle-pixel sets (the free roster).
            let species = String(scenario.dropFirst("pilot-".count))
            let egg: EggType = species == "walker" ? .crystal : .tiny
            for _ in 0..<14 { hatch(egg, species) }
            try? state.setCompanion(species)
            boardEgg()
        case "home-cocoa":
            hatch(.tiny, "cocoa")
            try? state.setCompanion("cocoa")
            boardEgg()
        case "home-long-ear":
            hatch(.forest, "long-ear")
            try? state.setCompanion("long-ear")
            boardEgg()
        case "home-day":
            timeOverride = .day
            boardEgg()
        case "hatch-ready":
            try? state.startEgg(.tiny, seed: 7, now: now)
            walk(EggType.tiny.targetSteps)
        case "reveal-rare", "reveal-large-type", "reveal-shiny":
            reveal = hatch(.moon, "moonwing", shiny: scenario != "reveal-rare")
            boardEgg()
        case "progress-61", "progress-large-type":
            page = 1
            boardEgg()
        case "progress-100":
            page = 1
            try? state.startEgg(.tiny, seed: 7, now: now)
            walk(EggType.tiny.targetSteps)
        case "friendship-1":
            // Board: Lv. 1 · 20 / 100 · Feed (0)
            page = 0
            boardEgg()
            _ = try? state.feed("mochi")
            _ = try? state.feed("mochi")
        case "fruit-available":
            page = 0
            boardEgg()
        case "friendship-5":
            page = 0
            for _ in 0..<26 { hatch(.tiny, "mochi") } // duplicates → Friendship EXP
            boardEgg()
        case "friendship-2", "friendship-3", "friendship-4":
            page = 0
            let duplicates = scenario == "friendship-2" ? 3 : scenario == "friendship-3" ? 7 : 13
            for _ in 0..<duplicates { hatch(.tiny, "mochi") }
            boardEgg()
        case "collection-1":
            page = 3
            boardEgg()
        case "free-complete":
            // A legacy three-bat save now sees the entire free collection.
            page = 3
            state.setUnlocked(false)
            hatch(.tiny, "cocoa")
            hatch(.tiny, "long-ear")
        case "collection-rare":
            page = 3
            addCollection()
            newlyUnlocked = ["galaxy"]
            boardEgg()
        case "egg-picker":
            page = 0
        case "settings":
            page = 1
            healthStatus = .connected
            boardEgg()
        case "health-error":
            page = 1
            healthStatus = .needsAttention
            boardEgg()
        case "phone-companion", "phone-batpedia", "phone-detail", "phone-pending", "phone-confirmed", "phone-stale":
            for _ in 0..<13 { hatch(.tiny, "mochi") }
            for _ in 0..<8 { hatch(.tiny, "sticky") }
            hatch(.crystal, "walker")
            let detailBat = launchRoster ? "cocoa" : "sticky"
            try? state.setCompanion(scenario == "phone-confirmed" ? detailBat : "mochi")
            page = ["phone-batpedia", "phone-detail", "phone-pending", "phone-confirmed"].contains(scenario) ? 1 : 0
            if ["phone-detail", "phone-pending", "phone-confirmed"].contains(scenario) { detailSpecies = detailBat }
            boardEgg()
        case "phone-batpedia-rare":
            page = 1
            addCollection()
            boardEgg()
        case "phone-egg-ready":
            try? state.startEgg(.tiny, seed: 7, now: now)
            walk(EggType.tiny.targetSteps)
        case "phone-certificate", "phone-certificate-shiny":
            page = 2
            hatch(.moon, "moonwing", shiny: scenario == "phone-certificate-shiny")
        case "phone-poster":
            page = 1
            addCollection()
            hatch(.crystal, "snow", shiny: true)
            hatch(.forest, "blossom")
        case "phone-recap", "phone-challenge", "phone-challenge-gold", "outfit-gold":
            page = scenario == "outfit-gold" ? 0 : 2
            let count = ["phone-challenge-gold", "outfit-gold"].contains(scenario) ? 5 : 1
            for _ in 0..<count { hatch(.tiny, "mochi") }
            boardEgg()
        case "phone-history":
            page = 2
            boardEgg()
        case "phone-settings", "phone-unlock":
            page = 0
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
    private static func seed(_ egg: EggType, _ species: String, shiny: Bool, isUnlocked: Bool = true) -> UInt64 {
        var s: UInt64 = 1
        while s < 3_000_000 {
            let roll = HatchEngine.roll(egg: egg, seed: s, isUnlocked: isUnlocked)
            if roll.species.id == species && roll.isShiny == shiny { return s }
            s += 1
        }
        return 1
    }
}
