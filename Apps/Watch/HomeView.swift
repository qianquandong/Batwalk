import SwiftUI
import BatwalkCore

/// A companion, fruit and an egg. Personality is performed, not listed.
struct HomeView: View {
    @Environment(GameStore.self) private var store
    @Binding var page: Int
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
    @State private var fruitToss = 0
    @State private var levelUps = 0

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                let time = DemoMode.timeOfDay(at: context.date)
                VStack(alignment: .leading, spacing: 4) {
                    content(time: time)
                }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .watchPageBackground(time, scenery: true)
            }
            .navigationTitle("")
            .toolbar {
                // The name sits where a Watch title lives — beside the time — so the
                // scene below belongs entirely to the bat.
                ToolbarItem(placement: .topBarLeading) {
                    if let companion = store.state.companion, !store.state.isEggReady {
                        nameRow(companion)
                    } else if store.state.companion == nil, store.state.egg != nil {
                        Text("First egg").font(BatwalkFont.caption).foregroundStyle(BatwalkColor.cloud)
                    }
                }
            }
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
            if typeSize.isAccessibilitySize {
                accessibleCompanionScene(companion, time: time)
            } else {
                companionScene(companion, time: time)
            }
        } else if let egg = state.egg {
            firstEggScene(egg)
        }
    }

    /// The bat is the hero: it takes every point the one slim info row at the
    /// bottom (fruit to give, steps to hatch) leaves free.
    private func companionScene(_ companion: OwnedBat, time: TimeOfDay) -> some View {
        GeometryReader { geo in
            let rowHeight: CGFloat = 36
            let batSize = max(72, min(geo.size.width * 0.96, geo.size.height - rowHeight - 12))
            let resting = BatMood.resting(at: time)
            VStack(spacing: 0) {
                Spacer(minLength: 0)
                // A real control, so Double Tap (watchOS 11) pets the bat too.
                Button { pet(companion) } label: {
                    BatHeroView(
                        speciesID: companion.speciesID,
                        shiny: companion.showsShiny,
                        mood: reaction ?? resting,
                        size: batSize,
                        bounceTrigger: petCount,
                        friendshipEXP: companion.friendshipEXP,
                        animationRequest: animationRequest,
                        showsKeepsake: false
                    )
                    .overlay { HeartBurst(trigger: petCount) }
                    .overlay { FruitToss(trigger: fruitToss) }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .doubleTapPrimaryAction()
                .onAppear { heroVisible = true; welcomeCompanion() }
                .onDisappear { heroVisible = false; clearReaction() }
                .accessibilityLabel(companion.displayName)
                .accessibilityHint(resting == .awake ? "Pet \(companion.displayName)" : "Wake \(companion.displayName)")
                Spacer(minLength: 0)
                infoRow(companion, height: rowHeight)
            }
            .padding(.horizontal, BatwalkSpacing.xs)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .batwalkAppear()
    }

    /// Larger text sizes read top to bottom and scroll; nothing is pinned to the
    /// screen height, so the bat is never pushed off the bottom.
    private func accessibleCompanionScene(_ companion: OwnedBat, time: TimeOfDay) -> some View {
        ScrollView {
            VStack(spacing: BatwalkSpacing.sm) {
                Button { pet(companion) } label: {
                    BatHeroView(speciesID: companion.speciesID, shiny: companion.showsShiny,
                                mood: reaction ?? BatMood.resting(at: time), size: 150,
                                bounceTrigger: petCount, friendshipEXP: companion.friendshipEXP,
                                animationRequest: animationRequest, showsKeepsake: false)
                        .overlay { HeartBurst(trigger: petCount) }
                        .overlay { FruitToss(trigger: fruitToss) }
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .doubleTapPrimaryAction()
                .onAppear { heroVisible = true; welcomeCompanion() }
                .onDisappear { heroVisible = false; clearReaction() }
                .accessibilityLabel(companion.displayName)
                feedButton(companion, height: 44)
                progressPill(height: 44)
            }
            .padding(.horizontal, BatwalkSpacing.xs)
        }
        .batwalkAppear()
    }

    private func nameRow(_ companion: OwnedBat) -> some View {
        HStack(spacing: 6) {
            Text(companion.companionTitle)
                .font(BatwalkFont.caption)
                .lineLimit(1).minimumScaleFactor(0.8)
                .foregroundStyle(BatwalkColor.cloud)
                .accessibilityAddTraits(.isHeader)
            FriendshipDots(level: Friendship.level(forEXP: companion.friendshipEXP), pulse: levelUps)
            Spacer(minLength: 0)
        }
    }

    private func infoRow(_ companion: OwnedBat, height: CGFloat) -> some View {
        HStack(spacing: 6) {
            feedButton(companion, height: height)
                .fixedSize(horizontal: true, vertical: false)
            progressPill(height: height)
        }
        .foregroundStyle(BatwalkColor.cloud)
    }

    private func feedButton(_ companion: OwnedBat, height: CGFloat) -> some View {
        Button { feed(companion) } label: {
            HStack(spacing: 4) {
                FruitIcon(size: 16)
                Text(store.state.fruit.formatted())
                    .font(BatwalkFont.caption).monospacedDigit()
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(BatwalkColor.cloud.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
        .disabled(store.state.fruit == 0)
        .opacity(store.state.fruit == 0 ? 0.45 : 1)
        .accessibilityLabel("Feed \(companion.displayName)")
        .accessibilityValue("\(store.state.fruit) fruit")
        .accessibilityHint(store.state.fruit == 0 ? "Walk to find fruit" : "Use one fruit")
    }

    /// "961 to hatch" — the number keeps its meaning without a label-free guess.
    private func progressPill(height: CGFloat) -> some View {
        Button {
            withAnimation(BatwalkMotion.page) { page = 1 }
        } label: {
            HStack(spacing: 4) {
                EggIcon(type: store.state.egg?.type ?? .tiny, size: 16)
                if let egg = store.state.egg {
                    Text(egg.stepsRemaining.formatted())
                        .font(BatwalkFont.caption).monospacedDigit()
                    Text("to hatch")
                        .font(BatwalkFont.micro)
                        .foregroundStyle(BatwalkColor.textSecondaryDark)
                } else {
                    Text("Next egg").font(BatwalkFont.micro)
                    Image(systemName: "plus").font(.system(size: 10, weight: .bold))
                }
            }
            .lineLimit(1).minimumScaleFactor(0.7)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, minHeight: height)
            .background(BatwalkColor.cloud.opacity(0.1), in: Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(store.state.egg == nil ? "Choose an egg" : "Egg progress")
        .accessibilityValue(store.state.egg.map { "\($0.stepsRemaining) steps to hatch" } ?? "No egg")
    }

    private func firstEggScene(_ egg: ActiveEgg) -> some View {
        GeometryReader { geo in
            let eggSize = max(84, min(geo.size.width * 0.5, geo.size.height - 70))
            VStack(spacing: BatwalkSpacing.sm) {
                Spacer(minLength: 0)
                EggSprite(type: egg.type, state: egg.visualState, size: eggSize)
                    .idleFloat()
                Spacer(minLength: 0)
                HStack(spacing: 6) {
                    EggIcon(type: egg.type, size: 16)
                    Text(egg.stepsRemaining.formatted())
                        .font(BatwalkFont.caption).monospacedDigit()
                    Text("to hatch")
                        .font(BatwalkFont.micro).foregroundStyle(BatwalkColor.textSecondaryDark)
                }
                .foregroundStyle(BatwalkColor.cloud)
                .padding(.horizontal, 12)
                .frame(minHeight: 36)
                .background(Capsule().fill(BatwalkColor.cloud.opacity(0.1)))
            }
            .padding(.bottom, BatwalkSpacing.xs)
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
        if after > before { Haptics.success(); levelUps += 1 } else { Haptics.light() }
        animationRequest = .interaction(.feed, speciesID: bat.speciesID, levelBefore: before, levelAfter: after)
    }

    private func pet(_ bat: OwnedBat) {
        let levelBefore = Friendship.level(forEXP: bat.friendshipEXP)
        do { _ = try store.mutate { try $0.pet(bat.speciesID, dayKey: DayKey.make(.now)) } }
        catch { Haptics.failure(); return }
        let levelAfter = Friendship.level(forEXP: store.state.collection[bat.speciesID]?.friendshipEXP ?? 0)
        if levelAfter > levelBefore { Haptics.success(); levelUps += 1 } else { Haptics.light() }
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

/// A quick choice on the wrist; pools, trials and purchase details live on iPhone.
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
                                Text(type.displayName).font(BatwalkFont.caption)
                                Spacer(minLength: 0)
                                Text(type.targetSteps.formatted()).font(BatwalkFont.micro).monospacedDigit()
                            }
                            .foregroundStyle(BatwalkColor.cloud)
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Start this egg. \(type.targetSteps) steps to hatch.")
                    }
                    if !store.state.isUnlocked {
                        Label("More on iPhone", systemImage: "iphone")
                            .font(BatwalkFont.micro).foregroundStyle(BatwalkColor.textSecondaryDark)
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
