import Foundation
import Observation
import BatwalkCore

/// Device-local teaching progress. It never writes the game save or grants a
/// reward; callers report actions only after GameStore has saved them.
@MainActor
@Observable
final class WatchOnboarding {
    enum Phase: String, Codable {
        case waitingForFirstHatch, greeting, feeding, nextEgg, complete
    }

    private struct Progress: Codable {
        var version = 1
        // An unstarted GameState is not saved yet and gets a new UUID on launch.
        // Bind the guide only once the real game has started.
        var saveID: UUID?
        var introductionSeen = false
        var eggHintSeen = false
        var hatchHintSeen = false
        var phase: Phase = .waitingForFirstHatch

        static func initial(for state: GameState) -> Self {
            guard state.hasStarted else { return Self() }
            // No guide record for an existing save means an upgrade or restore,
            // not a new player. Help can replay the optional hints later.
            return Self(saveID: state.saveID, introductionSeen: true,
                        eggHintSeen: true, hatchHintSeen: true, phase: .complete)
        }
    }

    @ObservationIgnored private let defaults: UserDefaults?
    @ObservationIgnored private let key: String
    @ObservationIgnored private var isPreview = false
    private var progress: Progress?

    var isPrepared: Bool { progress != nil }
    var phase: Phase { progress?.phase ?? .waitingForFirstHatch }
    var introductionSeen: Bool { progress?.introductionSeen ?? false }
    var eggHintSeen: Bool { progress?.eggHintSeen ?? false }
    var hatchHintSeen: Bool { progress?.hatchHintSeen ?? false }
    var isFirstCompanionGuide: Bool {
        phase == .greeting || phase == .feeding || phase == .nextEgg
    }

    /// Pass nil for an isolated, nonpersistent guide (for demos and previews).
    init(defaults: UserDefaults? = .standard, key: String = "batwalk.watchOnboarding.v1") {
        self.defaults = defaults
        self.key = key
        if let data = defaults?.data(forKey: key),
           let saved = try? JSONDecoder().decode(Progress.self, from: data),
           saved.version == 1 {
            progress = saved
        }
    }

    /// Explicit demo state is never inferred from a screenshot's invented save.
    static func preview(phase: Phase, introductionSeen: Bool = true,
                        eggHintSeen: Bool = true) -> WatchOnboarding {
        let guide = WatchOnboarding(defaults: nil)
        guide.isPreview = true
        guide.progress = Progress(introductionSeen: introductionSeen,
                                  eggHintSeen: eggHintSeen,
                                  hatchHintSeen: phase == .complete,
                                  phase: phase)
        return guide
    }

    /// Call before showing the first guide screen. Repeated calls are safe;
    /// restoring another save cannot carry over an unrelated tutorial step.
    func prepare(for state: GameState) {
        guard !isPreview else { return }
        if state.hasStarted, state.needsStepBaseline {
            // A collection restore is an established player even when its
            // saveID matches the previous local save or the intro was open.
            progress = .initial(for: state)
            persist()
            return
        }
        if var saved = progress {
            if let saveID = saved.saveID, saveID != state.saveID {
                progress = .initial(for: state)
            } else if saved.saveID == nil, state.hasStarted {
                saved.saveID = state.saveID
                progress = saved
            }
        } else {
            progress = .initial(for: state)
        }
        reconcileProgress(with: state)
        persist()
    }

    /// Recover the interval between a committed game action and its UI callback.
    /// Never create an egg, hatch twice, or treat viewing a tip as doing its task.
    func reconcile(with state: GameState) {
        prepare(for: state)
    }

    func finishIntroduction() { update { $0.introductionSeen = true } }
    func didViewEgg() { update { $0.eggHintSeen = true } }
    func dismissEggHint() { update { $0.eggHintSeen = true } }
    func didFinishHatchHelp() { update { $0.hatchHintSeen = true } }

    func didHatchFirstCompanion() {
        update {
            guard $0.phase == .waitingForFirstHatch else { return }
            $0.introductionSeen = true
            $0.hatchHintSeen = true
            $0.phase = .greeting
        }
    }

    func didPet(hasFruit: Bool) {
        update {
            guard $0.phase == .greeting else { return }
            $0.phase = hasFruit ? .feeding : .nextEgg
        }
    }

    func didFeed() {
        update {
            guard $0.phase == .feeding else { return }
            $0.phase = .nextEgg
        }
    }

    func skipInteraction() {
        update {
            guard $0.phase == .greeting || $0.phase == .feeding else { return }
            $0.phase = .nextEgg
        }
    }

    func didChooseEgg() {
        update {
            guard $0.phase == .nextEgg else { return }
            $0.phase = .complete
        }
    }

    func deferNextEgg() { didChooseEgg() }

    /// Help replays only the actions that exist in the current game. It does
    /// not reopen system permissions, replace an egg, or replay first launch.
    func replay(for state: GameState) {
        prepare(for: state)
        update {
            $0.introductionSeen = true
            $0.eggHintSeen = false
            $0.hatchHintSeen = state.egg == nil
            $0.phase = state.companion == nil ? .waitingForFirstHatch : .greeting
        }
    }

    private func reconcileProgress(with state: GameState) {
        guard var saved = progress else { return }
        if saved.phase == .waitingForFirstHatch, state.companion != nil {
            saved.introductionSeen = true
            saved.hatchHintSeen = true
            saved.phase = .greeting
        }
        if saved.phase == .feeding, state.fruit == 0 {
            saved.phase = .nextEgg
        }
        if saved.phase == .nextEgg, state.egg != nil, state.companion != nil {
            saved.phase = .complete
        }
        progress = saved
    }

    private func update(_ change: (inout Progress) -> Void) {
        guard var saved = progress else { return }
        change(&saved)
        progress = saved
        persist()
    }

    private func persist() {
        guard let defaults, let progress,
              let data = try? JSONEncoder().encode(progress) else { return }
        defaults.set(data, forKey: key)
    }
}
