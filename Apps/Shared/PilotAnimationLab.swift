import SwiftUI
import BatwalkCore

/// A presentation-only lab. No GameStore, save mutation, Health request or reward.
struct PilotAnimationLab: View {
    @State private var speciesID = "mochi"
    @State private var shiny = false
    @State private var level = 5
    @State private var selection = PreviewSelection.universal(.idle)
    @State private var replayID = UUID()
    @State private var choosingSpecies = false
    @State private var visible = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private enum PreviewSelection {
        case universal(UniversalAction)
        case special(String)
    }

    private var species: [Species] {
        Roster.catalog.filter {
            $0.wave <= SharedConfig.contentWave && PilotAnimationCatalog.speciesIDs.contains($0.id)
        }
    }

    private var actions: [BatAction] { PilotAnimationCatalog.playableActions(for: speciesID) }

    private var selectedClip: BatAnimationClip? {
        switch selection {
        case .universal(let action):
            return PilotAnimationCatalog.universal(for: speciesID, action: action)
        case .special(let id):
            return PilotAnimationCatalog.unique(for: speciesID, actionID: id, friendshipLevel: level)
        }
    }

    private var selectionName: String {
        switch selection {
        case .universal(let action): return name(for: action)
        case .special(let id): return actions.first { $0.id == id }?.name ?? "Preview"
        }
    }

    var body: some View {
        GeometryReader { geometry in
            #if os(watchOS)
            let canvas = min(100, max(60, geometry.size.height * 0.36))
            #else
            let canvas = min(220, max(140, geometry.size.height * 0.32))
            #endif
            VStack(spacing: 4) {
                VStack(spacing: 0) {
                    if let clip = selectedClip {
                        AnimationPreviewClip(clip: clip, shiny: shiny, size: canvas)
                            .id(replayID)
                    } else {
                        BatHeroView(speciesID: speciesID, shiny: shiny, size: canvas,
                                    friendshipEXP: Tuning.default.friendshipThresholds[level - 1],
                                    showsKeepsake: false)
                    }
                    Text(selectionName)
                        .font(BatwalkFont.micro)
                        .multilineTextAlignment(.center)
                        .lineLimit(2)
                }
                .frame(maxWidth: .infinity)
                .fixedSize(horizontal: false, vertical: true)

                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        Button { choosingSpecies = true } label: {
                            HStack {
                                Text(Roster.species(speciesID)?.name ?? speciesID)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 4)
                                Image(systemName: "chevron.down")
                            }
                            .frame(maxWidth: .infinity, minHeight: 44)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Choose a bat")
                        .accessibilityValue(Roster.species(speciesID)?.name ?? speciesID)

                        Toggle("Shiny", isOn: $shiny)
                            .font(BatwalkFont.caption)

                        Text("Basic moves").font(BatwalkFont.caption)
                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 6) {
                            ForEach(UniversalAction.allCases, id: \.self) { action in
                                Button(name(for: action)) {
                                    selection = .universal(action)
                                    replayID = UUID()
                                }
                                .font(BatwalkFont.caption)
                                .frame(maxWidth: .infinity, minHeight: 44)
                                .buttonStyle(.bordered)
                            }
                        }

                        if !actions.isEmpty {
                            Text("Personality").font(BatwalkFont.caption)
                            ForEach(actions, id: \.id) { action in
                                Button {
                                    selection = .special(action.id)
                                    replayID = UUID()
                                } label: {
                                    HStack(spacing: 6) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(action.name).font(BatwalkFont.caption)
                                            Text("Lv. \(action.unlockLevel)").font(BatwalkFont.micro)
                                                .foregroundStyle(.secondary)
                                        }
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        Image(systemName: "play.fill").font(BatwalkFont.micro)
                                    }
                                    .multilineTextAlignment(.leading)
                                    .frame(minHeight: 44)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .disabled(level < action.unlockLevel)
                                .accessibilityHint(level < action.unlockLevel ? "Raise the preview level to play this move." : "Play this move in the preview above.")
                            }
                        }

                        DisclosureGroup("Preview level") {
                            Picker("Friendship", selection: $level) {
                                ForEach(1...5, id: \.self) { Text("Lv. \($0)").tag($0) }
                            }
                            Text("Only changes this preview.")
                                .font(BatwalkFont.micro).foregroundStyle(.secondary)
                        }
                        .font(BatwalkFont.caption)

                        Text("Test preview. Your bats and progress stay as they are.")
                            .font(BatwalkFont.micro).foregroundStyle(.secondary)
                        if reduceMotion {
                            Text("Reduce Motion shows a still pose.")
                                .font(BatwalkFont.micro).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.bottom, 8)
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
        .navigationTitle("Animation preview")
        .environment(\.batPageVisible, visible && !choosingSpecies)
        .onAppear { visible = true }
        .onDisappear { visible = false }
        .onChange(of: speciesID) { _, _ in resetSelection() }
        .onChange(of: level) { _, _ in resetSelection() }
        .sheet(isPresented: $choosingSpecies) {
            NavigationStack {
                List(species) { bat in
                    Button {
                        speciesID = bat.id
                        choosingSpecies = false
                    } label: {
                        HStack {
                            Text(bat.name)
                            Spacer()
                            if speciesID == bat.id { Image(systemName: "checkmark") }
                        }
                    }
                }
                .navigationTitle("Choose a bat")
            }
        }
    }

    private func resetSelection() {
        selection = .universal(.idle)
        replayID = UUID()
    }

    private func name(for action: UniversalAction) -> String {
        switch action {
        case .idle: return "Idle"
        case .sleep: return "Sleep"
        case .fly: return "Fly"
        case .pet: return "Pet"
        case .eat: return "Feed"
        }
    }
}

/// Exact clip playback keeps base Pet/Feed review separate from the level-five
/// personality reactions used in the game. It shares the normal motion policy.
private struct AnimationPreviewClip: View {
    let clip: BatAnimationClip
    let shiny: Bool
    let size: CGFloat
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.isLuminanceReduced) private var luminanceReduced
    @Environment(\.batPageVisible) private var pageVisible
    @State private var frameIndex = 0
    @State private var unavailable = false

    private var active: Bool {
        BatPlaybackPolicy.permitsAnimation(pageVisible: pageVisible, sceneActive: scenePhase == .active,
                                           luminanceReduced: luminanceReduced, reduceMotion: reduceMotion)
    }

    private var frame: BatAnimationFrame? {
        guard !clip.frames.isEmpty else { return nil }
        return clip.frames[active ? min(frameIndex, clip.frames.count - 1) : 0]
    }

    var body: some View {
        Group {
            if unavailable {
                Text("Preview unavailable")
                    .font(BatwalkFont.caption)
                    .multilineTextAlignment(.center)
            } else {
                Image(frame?.assetName ?? "portrait_bat_\(clip.speciesID)")
                    .interpolation(.none)
                    .resizable()
                    .scaledToFit()
                    .hueRotation(.degrees(shiny ? 150 : 0))
                    .offset(x: active ? size * (frame?.offsetX ?? 0) : 0)
            }
        }
        .frame(width: size, height: size)
        .accessibilityLabel("\(Roster.species(clip.speciesID)?.name ?? "Bat"), \(shiny ? "Shiny" : "Normal") preview")
        .transaction { $0.animation = nil }
        .task(id: active) {
            frameIndex = 0
            unavailable = clip.frames.isEmpty || !clip.frames.allSatisfy { assetExists($0.assetName) }
            guard active, !unavailable else { return }
            do {
                while !Task.isCancelled {
                    for index in clip.frames.indices {
                        try Task.checkCancellation()
                        frameIndex = index
                        try await Task.sleep(for: .seconds(clip.frames[index].seconds))
                    }
                    frameIndex = 0
                    try await Task.sleep(for: .seconds(max(0.8, clip.restSeconds)))
                }
            } catch {
                // Navigation, wrist lowering and motion settings cancel playback.
            }
        }
    }
}
