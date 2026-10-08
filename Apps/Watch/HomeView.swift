import SwiftUI
import BatwalkCore

/// Home (board: Watch › 1. Home). The bat dominates the moonlit scene; one glass
/// card carries the name and a single progress pill. Tap the bat to pet it.
struct HomeView: View {
    @Environment(GameStore.self) private var store

    @State private var hatching: HatchPresentation?
    @State private var showEggPicker = false
    @State private var petCount = 0
    @State private var reaction: BatMood?
    @State private var reactionTask: Task<Void, Never>?
    @State private var demoRevealShown = false

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                let time = DemoMode.timeOfDay(at: context.date)
                content(time: time)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .watchPageBackground(time, scenery: true)
            }
            .navigationTitle(store.state.isEggReady ? "Ready!" : "Batwalk")
            .navigationDestination(for: String.self) { BatDetailView(speciesID: $0) }
        }
        .fullScreenCover(item: $hatching, onDismiss: {
            // Straight into choosing the next egg — keeps the loop moving (PRD §2.1).
            if store.state.egg == nil { showEggPicker = true }
        }) { presentation in
            HatchSequenceView(presentation: presentation) { hatching = nil }
        }
        .sheet(isPresented: $showEggPicker) { EggPickerView() }
        .onAppear {
            if let demo = DemoMode.reveal, !demoRevealShown {
                demoRevealShown = true
                hatching = HatchPresentation(result: demo, egg: demo.record.eggType, startRevealed: true)
            }
        }
    }

    @ViewBuilder
    private func content(time: TimeOfDay) -> some View {
        let state = store.state
        if let egg = state.egg, egg.isReady {
            HatchReadyView(egg: egg) { hatch(egg) }
                .batwalkAppear()
        } else if let companion = state.companion {
            companionScene(companion, time: time)
        } else if let egg = state.egg {
            firstEggScene(egg)
        }
    }

    private func companionScene(_ companion: OwnedBat, time: TimeOfDay) -> some View {
        GeometryReader { geo in
            let batSize = min(geo.size.width * 0.66, geo.size.height * 0.55)
            VStack(spacing: BatwalkSpacing.xs) {
                Spacer(minLength: 0)
                BatHeroView(
                    speciesID: companion.speciesID,
                    shiny: companion.showsShiny,
                    mood: reaction ?? BatMood.resting(at: time),
                    size: batSize,
                    bounceTrigger: petCount
                )
                .overlay { HeartBurst(trigger: petCount) }
                .contentShape(Rectangle())
                .onTapGesture { pet(companion) }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint("Pet \(companion.displayName)")
                Spacer(minLength: 0)
                VStack(spacing: 6) {
                    NavigationLink(value: companion.speciesID) {
                        HStack(spacing: 4) {
                            Text(companion.displayName)
                                .font(BatwalkFont.headline)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(BatwalkColor.textSecondaryDark)
                        }
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    progressPill
                }
                .batwalkGlassCard(padding: 8)
            }
            .padding(.horizontal, BatwalkSpacing.xs)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .batwalkAppear()
    }

    @ViewBuilder
    private var progressPill: some View {
        if let egg = store.state.egg {
            HStack(spacing: 6) {
                EggIcon(type: egg.type, size: 16)
                Text("\(egg.stepsRemaining.formatted()) steps to hatch")
                    .font(BatwalkFont.caption)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity)
            .background(Capsule().fill(Color.white.opacity(0.08)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .accessibilityElement(children: .combine)
        } else {
            Button {
                showEggPicker = true
            } label: {
                HStack(spacing: 6) { EggIcon(size: 16); Text("Pick an egg") }
            }
            .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 32))
        }
    }

    private func firstEggScene(_ egg: ActiveEgg) -> some View {
        VStack(spacing: BatwalkSpacing.sm) {
            Spacer(minLength: 0)
            EggSprite(type: egg.type, state: egg.visualState, size: 96)
                .idleFloat()
            Spacer(minLength: 0)
            HStack(spacing: 6) {
                EggIcon(type: egg.type, size: 16)
                Text("\(egg.stepsRemaining.formatted()) steps to hatch")
                    .font(BatwalkFont.caption)
                    .monospacedDigit()
            }
            .foregroundStyle(.white)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Capsule().fill(Color.white.opacity(0.08)))
            .overlay(Capsule().strokeBorder(.white.opacity(0.12), lineWidth: 1))
        }
        .padding(.bottom, BatwalkSpacing.xs)
        .batwalkAppear()
    }

    // MARK: Actions

    private func pet(_ bat: OwnedBat) {
        let levelBefore = Friendship.level(forEXP: bat.friendshipEXP)
        _ = try? store.mutate { try $0.pet(bat.speciesID, dayKey: DayKey.make(.now)) }
        let levelAfter = Friendship.level(forEXP: store.state.collection[bat.speciesID]?.friendshipEXP ?? 0)
        if levelAfter > levelBefore { Haptics.success() } else { Haptics.light() }
        petCount += 1
        reaction = .happy
        reactionTask?.cancel()
        reactionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.6))
            if !Task.isCancelled { reaction = nil }
        }
    }

    private func hatch(_ egg: ActiveEgg) {
        let isFirst = store.state.history.isEmpty
        // Save the hatch first, then animate: quitting mid-animation never loses the bat.
        guard let result = try? store.mutate({ try $0.hatch(now: .now) }) else {
            Haptics.failure()
            return
        }
        let id = result.record.speciesID
        store.analytics.log(isFirst ? .firstHatch : .batCollected, properties: [
            "species": id,
            "rarity": Roster.species(id)?.rarity.rawValue ?? "",
            "shiny": result.record.isShiny ? "true" : "false",
        ])
        if result.record.outcome == .duplicate {
            store.analytics.log(.duplicateFriendship, properties: ["species": id])
        }
        hatching = HatchPresentation(result: result, egg: egg.type, startRevealed: false)
    }
}

/// Next-egg chooser, shown after every hatch.
struct EggPickerView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 6) {
                    ForEach(EggType.allCases.filter(\.isPickable), id: \.self) { type in
                        let available = store.state.pickableEggs.contains(type)
                        Button {
                            start(type)
                        } label: {
                            HStack(spacing: BatwalkSpacing.sm) {
                                EggIcon(type: type, size: 26)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(type.displayName).font(BatwalkFont.caption)
                                    Text(available ? "\(type.targetSteps.formatted()) steps" : "Full unlock")
                                        .font(BatwalkFont.micro)
                                        .foregroundStyle(BatwalkColor.textSecondaryDark)
                                }
                                Spacer(minLength: 0)
                                if !available {
                                    Image(systemName: "lock.fill")
                                        .font(.system(size: 10))
                                        .foregroundStyle(BatwalkColor.textSecondaryDark)
                                }
                            }
                            .foregroundStyle(.white)
                            .batwalkGlassCard(padding: 8, radius: 14)
                            .opacity(available ? 1 : 0.55)
                        }
                        .buttonStyle(PressableStyle())
                        .disabled(!available)
                    }
                }
                .padding(.horizontal, 2)
            }
            .navigationTitle("Next Egg")
            .watchPageBackground()
        }
    }

    private func start(_ type: EggType) {
        do {
            try store.mutate { try $0.startEgg(type, seed: UInt64.random(in: .min ... .max), now: .now) }
            dismiss()
        } catch {
            Haptics.failure()
        }
    }
}
