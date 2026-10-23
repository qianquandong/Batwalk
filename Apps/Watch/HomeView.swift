import SwiftUI
import BatwalkCore

/// The companion has the stage; Feed is the only visible control.
struct HomeView: View {
    @Environment(GameStore.self) private var store
    @Binding var page: Int
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.batPageVisible) private var pageVisible
    @Environment(\.isLuminanceReduced) private var luminanceReduced
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var hatching: HatchPresentation?
    @State private var showEggPicker = DemoMode.scenario == "egg-picker"
    @State private var petCount = 0
    @State private var reaction: BatMood?
    @State private var reactionTask: Task<Void, Never>?
    @State private var demoRevealShown = false
    @State private var animationRequest: BatAnimationRequest?
    @State private var heroVisible = false
    @State private var fruitToss = 0

    var body: some View {
        TimelineView(.everyMinute) { context in
            let time = DemoMode.timeOfDay(at: context.date)
            content(time: time)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .watchPageBackground(time, scenery: false)
        }
        .fullScreenCover(item: $hatching, onDismiss: {
            // Straight into choosing the next egg — keeps the loop moving (PRD §2.1).
            if store.state.egg == nil { showEggPicker = true }
        }) { presentation in
            HatchSequenceView(presentation: presentation) {
                // Only one egg to choose from: start it without a detour (Q2).
                if store.state.pickableEggs == [.tiny], store.state.egg == nil {
                    do { try store.mutate { try $0.startEgg(.tiny, seed: UInt64.random(in: .min ... .max), now: .now) } }
                    catch { return }
                }
                hatching = nil
                if store.state.history.count == 1 && !store.isDemo {
                    Task { await HatchNotifier.requestPermission() }
                }
            }
        }
        .sheet(isPresented: $showEggPicker) { EggPickerView() }
        .onAppear {
            if let demo = DemoMode.reveal, !demoRevealShown {
                demoRevealShown = true
                hatching = HatchPresentation(result: demo, egg: demo.record.eggType, startRevealed: true)
            }
        }
        .onChange(of: scenePhase) { _, _ in welcomeCompanion() }
        .onChange(of: pageVisible) { _, visible in
            if visible { welcomeCompanion() } else { clearReaction() }
        }
        .onChange(of: luminanceReduced) { _, _ in welcomeCompanion() }
        .onChange(of: store.state.lifetimeCreditedSteps) { _, _ in welcomeCompanion() }
        .onChange(of: store.state.companionID) { _, _ in
            clearReaction()
            welcomeCompanion()
        }
        .onDisappear { clearReaction() }
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

    /// Reserve only the Feed touch target below the full animation canvas.
    /// Names and egg progress do not compete with the companion's activity space.
    private func companionScene(_ companion: OwnedBat, time: TimeOfDay) -> some View {
        GeometryReader { geo in
            let stageHeight = max(1, geo.size.height - 52)
            let canvas = min(geo.size.width - 8, stageHeight)
            VStack(spacing: 0) {
                petButton(companion, time: time, size: canvas)
                    .frame(maxWidth: .infinity)
                    .frame(height: stageHeight)
                FeedButton(fruit: store.state.fruit) { feed(companion) }
                    .frame(height: 44)
                    .padding(.bottom, 8)
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .ignoresSafeArea(.container, edges: .bottom)
        .batwalkAppear()
    }

    private func petButton(_ companion: OwnedBat, time: TimeOfDay, size: CGFloat) -> some View {
        let resting = BatMood.resting(at: time)
        return Button { pet(companion) } label: {
            BatHeroView(speciesID: companion.speciesID, shiny: companion.showsShiny,
                        mood: reaction ?? resting, size: size, bounceTrigger: petCount,
                        friendshipEXP: companion.friendshipEXP,
                        animationRequest: animationRequest, showsKeepsake: false)
                .overlay { ChallengeOutfitOverlay(outfit: store.state.outfit(for: companion.speciesID)) }
                .overlay { HeartBurst(trigger: petCount) }
                .overlay { FruitToss(trigger: fruitToss) }
                .contentShape(Rectangle())
        }
        .buttonStyle(PressableStyle())
        .doubleTapPrimaryAction()
        .onAppear { heroVisible = true; welcomeCompanion() }
        .onDisappear { heroVisible = false; clearReaction() }
        .accessibilityLabel(companion.displayName)
        .accessibilityHint(resting == .awake ? "Pet \(companion.displayName)" : "Wake \(companion.displayName)")
    }

    private func firstEggScene(_ egg: ActiveEgg) -> some View {
        GeometryReader { geo in
            VStack(spacing: 4) {
                Text("A little beginning")
                    .font(BatwalkFont.rounded(.caption2, weight: .medium))
                    .foregroundStyle(BatwalkColor.textSecondaryDark)
                    .lineLimit(1).minimumScaleFactor(0.7)
                Spacer(minLength: 0)
                EggSprite(type: egg.type, state: egg.visualState,
                          size: min(100, geo.size.height * 0.58))
                    .idleFloat()
                Spacer(minLength: 0)
                Button { withAnimation(BatwalkMotion.page) { page = 1 } } label: {
                    Label(egg.stepsRemaining.formatted(), systemImage: "figure.walk")
                        .font(BatwalkFont.caption).monospacedDigit()
                        .frame(minWidth: 64, minHeight: 44)
                }
                .buttonStyle(PressableStyle())
                .foregroundStyle(BatwalkColor.cloud)
                .accessibilityLabel("Egg progress")
                .accessibilityValue("\(egg.stepsRemaining) steps to hatch")
            }
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .batwalkAppear()
    }

    // MARK: Actions

    private func feed(_ bat: OwnedBat) {
        let before = Friendship.level(forEXP: bat.friendshipEXP)
        do { try store.mutate { try $0.feed(bat.speciesID) } }
        catch { Haptics.failure(); return }
        let after = Friendship.level(forEXP: store.state.collection[bat.speciesID]?.friendshipEXP ?? 0)
        store.analytics.log(.feedBat, properties: ["species": bat.speciesID])
        fruitToss += 1
        petCount += 1
        if after > before { Haptics.success() } else { Haptics.light() }
        animationRequest = .interaction(.feed, speciesID: bat.speciesID, levelBefore: before, levelAfter: after)
    }

    private func pet(_ bat: OwnedBat) {
        let levelBefore = Friendship.level(forEXP: bat.friendshipEXP)
        do { _ = try store.mutate { try $0.pet(bat.speciesID, dayKey: DayKey.make(.now)) } }
        catch { Haptics.failure(); return }
        let levelAfter = Friendship.level(forEXP: store.state.collection[bat.speciesID]?.friendshipEXP ?? 0)
        if levelAfter > levelBefore { Haptics.success() } else { Haptics.light() }
        petCount += 1
        if PilotAnimationCatalog.speciesIDs.contains(bat.speciesID) {
            animationRequest = .interaction(.pet, speciesID: bat.speciesID,
                                            levelBefore: levelBefore, levelAfter: levelAfter)
            return
        }
        // Tapping a sleeping / drowsy bat wakes it (CARE: feed · pet · wake, PRD §2.4).
        let resting = BatMood.resting(at: DemoMode.timeOfDay(at: .now))
        reaction = (resting == .sleeping || resting == .drowsy) ? .awake : .happy
        reactionTask?.cancel()
        reactionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            if !Task.isCancelled { reaction = nil }
        }
    }

    private func clearReaction() {
        reactionTask?.cancel()
        reaction = nil
        animationRequest = nil
    }

    private func welcomeCompanion() {
        guard heroVisible, pageVisible, scenePhase == .active, !luminanceReduced,
              hatching == nil, !showEggPicker, !store.state.isEggReady,
              let bat = store.state.companion,
              PilotAnimationCatalog.speciesIDs.contains(bat.speciesID) else { return }
        if let request = store.companionOpeningRequest(time: DemoMode.timeOfDay(at: .now),
                                                       motionAllowed: !reduceMotion) {
            animationRequest = request
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
            "egg": egg.type.rawValue,
        ])
        if result.record.outcome == .duplicate {
            store.analytics.log(.duplicateFriendship, properties: ["species": id, "moonDust": "\(result.moonDustGained)"])
        }
        hatching = HatchPresentation(result: result, egg: egg.type, startRevealed: false)
    }
}

/// A quick choice on the wrist; pool explanations live on iPhone.
struct EggPickerView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 8) {
                    ForEach(store.state.pickableEggs, id: \.self) { type in
                        Button { start(type) } label: {
                            HStack(spacing: 10) {
                                EggIcon(type: type, size: 30)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(type.displayName).font(BatwalkFont.caption)
                                        .lineLimit(2).multilineTextAlignment(.leading)
                                    Text("\(type.targetSteps.formatted()) steps")
                                        .font(BatwalkFont.micro).monospacedDigit()
                                        .foregroundStyle(BatwalkColor.textSecondaryDark)
                                }
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(BatwalkColor.cloud)
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Start this egg. \(type.targetSteps) steps to hatch.")
                    }
                }
                .padding(.horizontal, BatwalkSpacing.xs)
            }
            .navigationTitle("Next egg")
            .watchPageBackground()
        }
    }

    private func start(_ type: EggType) {
        do {
            try store.mutate { try $0.startEgg(type, seed: UInt64.random(in: .min ... .max), now: .now) }
            dismiss()
        } catch { Haptics.failure() }
    }
}
