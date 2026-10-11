import SwiftUI
import BatwalkCore

private struct BatPageVisibleKey: EnvironmentKey {
    static let defaultValue = true
}

extension EnvironmentValues {
    /// Set explicitly by the Watch pager: adjacent pages can remain mounted.
    var batPageVisible: Bool {
        get { self[BatPageVisibleKey.self] }
        set { self[BatPageVisibleKey.self] = newValue }
    }
}

/// A cancellable, low-frequency frame player; no display link or background timer.
/// Each request is consumed before playback, so lowering the wrist never replays it.
struct BatAnimationPlayer: View {
    let speciesID: String
    let mood: BatMood
    let size: CGFloat
    let friendshipLevel: Int
    var request: BatAnimationRequest?

    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var luminanceReduced
    @Environment(\.batPageVisible) private var pageVisible
    @State private var frameName: String?
    @State private var consumption = BatAnimationConsumption()
    @State private var ambientMemory = BatAmbientMemory()
    @State private var observedLevel: Int?
    @State private var offsetX = 0.0

    private var active: Bool {
        BatPlaybackPolicy.permitsAnimation(pageVisible: pageVisible, sceneActive: scenePhase == .active,
                                           luminanceReduced: luminanceReduced, reduceMotion: reduceMotion)
    }

    private struct PlaybackKey: Hashable {
        let speciesID: String
        let mood: BatMood
        let active: Bool
        let level: Int
        let request: BatAnimationRequest?
    }

    var body: some View {
        let still = PilotAnimationCatalog.still(for: speciesID, mood: mood)
        // The fallback changes synchronously when motion is disabled, even before
        // SwiftUI has cancelled the sleeping task.
        Image((active ? frameName : nil) ?? still ?? "portrait_bat_\(speciesID)")
            .interpolation(.none)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .offset(x: active ? size * offsetX : 0)
            .accessibilityLabel(Roster.species(speciesID)?.name ?? "Bat")
            .transaction { $0.animation = nil }
            .task(id: PlaybackKey(speciesID: speciesID, mood: mood, active: active,
                                  level: friendshipLevel, request: request)) {
                frameName = nil
                offsetX = 0
                let hasRequest = consumption.consume(request, enabled: active)
                let newActions = ActionCatalog.actions(for: speciesID).filter {
                    $0.unlockLevel > (observedLevel ?? friendshipLevel) && $0.unlockLevel <= friendshipLevel
                }.map(\.id)
                observedLevel = friendshipLevel
                guard active else { return }
                let time: TimeOfDay = mood == .sleeping ? .day : mood == .drowsy ? .dusk : .night
                do {
                    if hasRequest || !newActions.isEmpty {
                        let combined = BatAnimationRequest(hasRequest ? request?.events ?? [] : [],
                            actionIDs: (hasRequest ? request?.actionIDs ?? [] : []) + newActions)
                        for clip in PilotAnimationCatalog.clips(for: combined, speciesID: speciesID,
                                                               friendshipLevel: friendshipLevel) {
                            ambientMemory.record(clip, time: time, day: DayKey.make(.now))
                            try await play(clip)
                        }
                    }
                    guard let ambient = PilotAnimationCatalog.ambient(for: speciesID, mood: mood) else { return }
                    var nextBeat = Date.now.addingTimeInterval(8)
                    while !Task.isCancelled {
                        try await play(ambient)
                        frameName = ambient.frames.first?.assetName
                        offsetX = 0
                        try await Task.sleep(for: .seconds(ambient.restSeconds))
                        if Date.now >= nextBeat {
                            let now = Date.now
                            if let special = ambientMemory.next(speciesID: speciesID, friendshipLevel: friendshipLevel,
                                time: time, day: DayKey.make(now), minute: Int(now.timeIntervalSince1970 / 60),
                                rareRoll: Int.random(in: 0..<24)) {
                                try await play(special)
                            }
                            nextBeat = Date.now.addingTimeInterval(16)
                        }
                    }
                } catch {
                    // Cancellation belongs to this task only. Do not clear a new
                    // task's frame or request from an old task's completion.
                }
            }
            .onDisappear { frameName = nil }
    }

    @MainActor
    private func play(_ clip: BatAnimationClip) async throws {
        // Verify the whole clip before showing it; missing art stays on its still.
        guard clip.frames.allSatisfy({ assetExists($0.assetName) }) else {
            try await Task.sleep(for: .seconds(4))
            return
        }
        for frame in clip.frames {
            try Task.checkCancellation()
            frameName = frame.assetName
            offsetX = frame.offsetX
            try await Task.sleep(for: .seconds(frame.seconds))
        }
    }
}
