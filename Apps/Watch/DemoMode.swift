import Foundation
import BatwalkCore

/// Screenshot / review scenarios, selected with a launch argument:
///     -BatwalkDemo <scenario>
/// Used by .github/workflows/screenshots.yml to capture the Watch app in the
/// simulator. A demo state lives only in memory: it is never saved, synced,
/// or fed by HealthKit. Without the argument this file does nothing.
enum DemoMode {
    static let scenarios = [
        "egg-new", "egg-cracked", "egg-ready",
        "bat-day", "bat-dusk", "bat-night",
        "reveal-rare", "walk", "care", "collection",
    ]

    static let scenario: String? = {
        let args = ProcessInfo.processInfo.arguments
        guard let i = args.firstIndex(of: "-BatwalkDemo"), i + 1 < args.count else { return nil }
        return args[i + 1]
    }()

    static var isActive: Bool { scenario != nil }

    /// Forced Day / Dusk / Night for the scenario (nil = real clock).
    private(set) static var timeOverride: TimeOfDay?
    /// Vertical page to open: 0 Home · 1 Walk · 2 Care · 3 Bats.
    private(set) static var page = 0
    /// Hatch result to present as the reveal sheet on launch.
    private(set) static var reveal: HatchResult?

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
        state.setUnlocked(true)
        state.start(seed: 1, now: now)

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

        switch scenario {
        case "egg-new":
            walk(300); timeOverride = .night
        case "egg-cracked":
            walk(1_300); timeOverride = .day
        case "egg-ready":
            walk(2_000); timeOverride = .night
        default:
            walk(2_000)
            _ = try? state.hatch(now: now) // Mochi, the starter
            try? state.rename("mochi", to: "Mochi")
            switch scenario {
            case "bat-day": timeOverride = .day
            case "bat-dusk": timeOverride = .dusk
            case "reveal-rare":
                timeOverride = .night
                reveal = hatch(.moon, "moonwing")
            case "walk": timeOverride = .night; page = 1
            case "care": timeOverride = .night; page = 2
            case "collection":
                timeOverride = .night; page = 3
                hatch(.forest, "strawberry")
                hatch(.moon, "moonwing")
                hatch(.moon, "galaxy")
                hatch(.tiny, "cocoa")
                hatch(.crystal, "golden")
                hatch(.tiny, "mochi") // duplicate → Friendship
            default: timeOverride = .night
            }
            try? state.startEgg(.forest, seed: 7, now: now)
            walk(1_700)
        }
        return state
    }

    /// First seed whose roll yields `species` (deterministic, so screenshots are stable).
    private static func seed(_ egg: EggType, _ species: String, shiny: Bool) -> UInt64 {
        for s in UInt64(1)...UInt64(3_000_000) {
            let roll = HatchEngine.roll(egg: egg, seed: s, isUnlocked: true)
            if roll.species.id == species && roll.isShiny == shiny { return s }
        }
        return 1
    }
}
