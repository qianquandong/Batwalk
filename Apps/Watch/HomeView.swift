import SwiftUI
import BatwalkCore

/// Home (board: Watch › 1. Home). The bat dominates the moonlit scene; one glass
/// card carries the name and a single progress pill. Tap the bat to pet it.
struct HomeView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.scenePhase) private var scenePhase
    @Environment(\.batPageVisible) private var pageVisible
    @Environment(\.isLuminanceReduced) private var luminanceReduced
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @Environment(\.dynamicTypeSize) private var typeSize
    @State private var hatching: HatchPresentation?
    @State private var showEggPicker = false
    @State private var petCount = 0
    @State private var reaction: BatMood?
    @State private var reactionTask: Task<Void, Never>?
    @State private var demoRevealShown = false
    @State private var animationRequest: BatAnimationRequest?
    @State private var heroVisible = false
    @State private var showArrival = false

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                let time = DemoMode.timeOfDay(at: context.date)
                VStack(alignment: .leading, spacing: 4) {
                    if store.state.companion == nil || store.state.isEggReady {
                        Text(store.state.isEggReady ? "Ready!" : "Batwalk")
                            .font(BatwalkFont.headline).foregroundStyle(BatwalkColor.cloud)
                            .padding(.horizontal, 8).accessibilityAddTraits(.isHeader)
                    }
                    content(time: time)
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .watchPageBackground(time, scenery: true)
            }
            .navigationTitle("")
            .navigationDestination(for: String.self) { BatDetailView(speciesID: $0) }
        }
        .fullScreenCover(item: $hatching, onDismiss: {
            // Straight into choosing the next egg — keeps the loop moving (PRD §2.1).
            if store.state.egg == nil { showEggPicker = true }
        }) { presentation in
            HatchSequenceView(presentation: presentation) {
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
        .task(id: store.companionArrival) {
            guard store.companionArrival != nil else { return }
            showArrival = true
            try? await Task.sleep(for: .seconds(3))
            showArrival = false
        }
    }

    @ViewBuilder
    private func content(time: TimeOfDay) -> some View {
        let state = store.state
        if let egg = state.egg, egg.isReady {
            HatchReadyView(egg: egg) { hatch(egg) }
                .batwalkAppear()
        } else if let companion = state.companion {
            if typeSize.isAccessibilitySize {
                ScrollView { companionScene(companion, time: time).frame(height: 360) }
            } else {
                companionScene(companion, time: time)
            }
        } else if let egg = state.egg {
            firstEggScene(egg)
        }
    }

    private func companionScene(_ companion: OwnedBat, time: TimeOfDay) -> some View {
        GeometryReader { geo in
            let batSize = min(geo.size.width * 0.80, geo.size.height * 0.52)
            VStack(spacing: 3) {
                NavigationLink(value: companion.speciesID) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(companion.companionTitle)
                            .font(BatwalkFont.rounded(.title3, weight: .bold))
                            .lineLimit(1).minimumScaleFactor(0.75)
                        Label("Lv. \(Friendship.level(forEXP: companion.friendshipEXP))", systemImage: "heart.fill")
                            .font(BatwalkFont.micro).foregroundStyle(BatwalkColor.rose)
                    }
                    .foregroundStyle(BatwalkColor.cloud)
                    .frame(maxWidth: .infinity, minHeight: 40, alignment: .leading)
                }.buttonStyle(.plain)
                Spacer(minLength: 0)
                BatHeroView(
                    speciesID: companion.speciesID,
                    shiny: companion.showsShiny,
                    mood: reaction ?? BatMood.resting(at: time),
                    size: batSize,
                    bounceTrigger: petCount,
                    friendshipEXP: companion.friendshipEXP,
                    animationRequest: animationRequest,
                    showsKeepsake: false
                )
                .onAppear { heroVisible = true; welcomeCompanion() }
                .onDisappear { heroVisible = false; clearReaction() }
                .overlay { HeartBurst(trigger: petCount) }
                .contentShape(Rectangle())
                .onTapGesture { pet(companion) }
                .accessibilityAddTraits(.isButton)
                .accessibilityHint(BatMood.resting(at: time) == .awake ? "Pet \(companion.displayName)" : "Wake \(companion.displayName)")
                Spacer(minLength: 0)
                Text(showArrival ? "\(companion.companionTitle) is here" : (BatMood.resting(at: time) == .awake ? "Tap to pet" : "Tap to wake"))
                    .font(BatwalkFont.micro).foregroundStyle(BatwalkColor.textSecondaryDark)
                    .opacity(luminanceReduced ? 0 : 1)
                    .accessibilityHidden(true)
                progressPill.padding(.top, 5)

            }
            .padding(.horizontal, BatwalkSpacing.xs)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .batwalkAppear()
    }

    @ViewBuilder
    private var progressPill: some View {
        if let egg = store.state.egg {
            HatchProgressSummary(egg: egg, compact: true)
                .padding(.horizontal, 2)
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
        do { _ = try store.mutate { try $0.pet(bat.speciesID, dayKey: DayKey.make(.now)) } }
        catch { Haptics.failure(); return }
        let levelAfter = Friendship.level(forEXP: store.state.collection[bat.speciesID]?.friendshipEXP ?? 0)
        if levelAfter > levelBefore { Haptics.success() } else { Haptics.light() }
        petCount += 1
        if PilotAnimationCatalog.speciesIDs.contains(bat.speciesID) {
            let unlocked = levelBefore < 4 && levelAfter >= 4
            animationRequest = BatAnimationRequest(unlocked ? [.pet, .signature] : [.pet])
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
        let events = store.companionVisitEvents(day: DayKey.make(.now))
        let level = Friendship.level(forEXP: bat.friendshipEXP)
        let playable = events.filter {
            PilotAnimationCatalog.reaction(for: bat.speciesID, event: $0, friendshipLevel: level) != nil
        }
        if !playable.isEmpty && !reduceMotion { animationRequest = BatAnimationRequest(playable) }
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
                                    if available {
                                        Text(type.pool(isUnlocked: store.state.isUnlocked).compactMap { Roster.species($0)?.name }.joined(separator: ", "))
                                            .font(BatwalkFont.micro)
                                            .foregroundStyle(BatwalkColor.textSecondaryDark)
                                    }
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
