import SwiftUI
import BatwalkCore

/// The companion has the stage; Feed is the only visible control.
struct HomeView: View {
    @Environment(GameStore.self) private var store
    @Environment(WatchOnboarding.self) private var onboarding
    @Binding var page: Int
    @Environment(\.dynamicTypeSize) private var typeSize
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
    @State private var feedback: String?
    @State private var feedbackTask: Task<Void, Never>?
    @State private var deferPickerAfterReveal = false
    @State private var showFruitHelp = DemoMode.scenario == "fruit-help"

    var body: some View {
        TimelineView(.everyMinute) { context in
            let time = DemoMode.timeOfDay(at: context.date)
            content(time: time)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .watchPageBackground(time, scenery: false)
        }
        .fullScreenCover(item: $hatching, onDismiss: {
            // A first companion gets a quiet greeting before the next choice.
            if !deferPickerAfterReveal, store.state.egg == nil { showEggPicker = true }
            deferPickerAfterReveal = false
        }) { presentation in
            HatchSequenceView(presentation: presentation) {
                // Only one egg to choose from: start it without a detour (Q2).
                if !presentation.isFirstCompanion, store.state.pickableEggs == [.tiny], store.state.egg == nil {
                    do { try store.mutate { try $0.startEgg(.tiny, seed: UInt64.random(in: .min ... .max), now: .now, tuning: store.tuning) } }
                    catch { return }
                }
                hatching = nil
            }
        }
        .sheet(isPresented: $showEggPicker) { EggPickerView() }
        .sheet(isPresented: $showFruitHelp) { FruitHelpView() }
        .onAppear {
            if let demo = DemoMode.reveal, !demoRevealShown {
                demoRevealShown = true
                let first = DemoMode.scenario?.hasPrefix("first-reveal") == true
                deferPickerAfterReveal = first
                hatching = HatchPresentation(result: demo, egg: demo.record.eggType,
                                             startRevealed: true, isFirstCompanion: first)
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
        .onChange(of: onboarding.phase) { _, phase in
            // Replaying tips with an active egg must not offer to replace it.
            if phase == .nextEgg, store.state.egg != nil { onboarding.didChooseEgg() }
        }
        .onDisappear { clearReaction(); feedbackTask?.cancel(); feedback = nil }
    }

    @ViewBuilder
    private func content(time: TimeOfDay) -> some View {
        let state = store.state
        if let egg = state.egg, egg.isReady {
            HatchReadyView(egg: egg, showHint: !onboarding.hatchHintSeen) { hatch(egg) }
                .batwalkAppear()
        } else if let companion = state.companion {
            companionScene(companion, time: time)
        } else if let egg = state.egg {
            firstEggScene(egg)
        }
    }

    /// Ordinary visits keep the full stage. Optional lessons reserve their own
    /// space; ordinary feedback uses the existing reaction rather than resizing it.
    private func companionScene(_ companion: OwnedBat, time: TimeOfDay) -> some View {
        GeometryReader { geo in
            let controlsHeight: CGFloat = onboarding.phase == .greeting ? 0 : onboarding.phase == .nextEgg ? 88 : 44
            let guideHeight: CGFloat = showsContextGuide ? 44 : 0
            let stageHeight = max(44, geo.size.height - controlsHeight - guideHeight - 8)
            let canvas = min(geo.size.width - 8, stageHeight)
            VStack(spacing: 0) {
                if onboarding.phase == .nextEgg {
                    ScrollView { guide.padding(.vertical, BatwalkSpacing.xs) }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if typeSize.isAccessibilitySize {
                    ScrollView {
                        VStack(spacing: BatwalkSpacing.xs) {
                            guide
                            petButton(companion, time: time, size: 80)
                        }.frame(maxWidth: .infinity)
                    }
                } else {
                    petButton(companion, time: time, size: canvas)
                        .frame(maxWidth: .infinity)
                        .frame(height: stageHeight)
                    if showsContextGuide { guide.frame(height: guideHeight) }
                }
                if onboarding.phase == .nextEgg {
                    Button("Choose an egg") { showEggPicker = true }
                        .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 44))
                    Button("Later") { onboarding.deferNextEgg() }
                        .font(BatwalkFont.caption)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .buttonStyle(.plain)
                } else if onboarding.phase != .greeting {
                    FeedButton(fruit: store.state.fruit, allowsEmptyTap: true) { feed(companion) }
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, BatwalkSpacing.xs)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .batwalkAppear()
    }

    private var guideText: String? {
        if needsEggGuide { return "Turn the Crown\nfor your egg." }
        guard onboarding.isFirstCompanionGuide else { return nil }
        if let feedback { return feedback }
        switch onboarding.phase {
        case .greeting: return "Tap to say hi."
        case .feeding: return "Try a little fruit."
        case .nextEgg: return "Your next little walk."
        case .waitingForFirstHatch, .complete: return nil
        }
    }

    private var needsEggGuide: Bool {
        onboarding.phase == .complete && !onboarding.eggHintSeen && store.state.egg != nil
    }

    private var showsContextGuide: Bool { onboarding.isFirstCompanionGuide || needsEggGuide }

    @ViewBuilder private var guide: some View {
        if let text = guideText {
            HStack(spacing: 0) {
                if needsEggGuide {
                    Button { page = 1 } label: { guideLabel(text).frame(minHeight: 44) }
                        .buttonStyle(.plain)
                        .accessibilityHint("Open your egg progress")
                } else {
                    guideLabel(text)
                }
                if onboarding.phase == .greeting || onboarding.phase == .feeding || needsEggGuide {
                    Button {
                        if needsEggGuide { onboarding.dismissEggHint() }
                        else { onboarding.skipInteraction() }
                    } label: {
                        Image(systemName: "xmark").font(BatwalkFont.micro)
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Skip this tip")
                }
            }
            .frame(minHeight: 44)
        }
    }

    private func guideLabel(_ text: String) -> some View {
        Text(text)
            .font(BatwalkFont.caption)
            .foregroundStyle(BatwalkColor.textSecondaryDark)
            .multilineTextAlignment(.center)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity)
    }

    private func petButton(_ companion: OwnedBat, time: TimeOfDay, size: CGFloat) -> some View {
        let resting = BatMood.resting(at: time)
        return Button { pet(companion) } label: {
            BatHeroView(speciesID: companion.speciesID, shiny: companion.showsShiny,
                        mood: reaction ?? resting, size: size, bounceTrigger: petCount,
                        friendshipEXP: companion.friendshipEXP,
                        animationRequest: animationRequest, showsKeepsake: false)
                .overlay { ChallengeOutfitOverlay(outfit: store.state.outfit(for: companion.speciesID)) }
                .overlay { BirthdayHatOverlay(speciesID: companion.speciesID, year: store.state.birthdayHatYear(for: companion.speciesID), mood: reaction ?? resting) }
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
                if typeSize.isAccessibilitySize {
                    ScrollView { firstEggContent(egg, size: 48) }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ViewThatFits(in: .vertical) {
                        firstEggContent(egg, size: min(60, max(24, geo.size.height - 124)))
                        ScrollView { firstEggContent(egg, size: 24) }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                Button { withAnimation(reduceMotion ? nil : BatwalkMotion.page) { page = 1 } } label: {
                    Text("View progress")
                        .font(BatwalkFont.caption)
                }
                .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 44))
                .fixedSize(horizontal: false, vertical: true)
                .accessibilityLabel("Egg progress")
                .accessibilityValue("\(egg.stepsRemaining) steps to hatch")
            }
            .padding(.horizontal, BatwalkSpacing.sm)
            .frame(width: geo.size.width, height: geo.size.height)
        }
        .batwalkAppear()
    }

    private func firstEggContent(_ egg: ActiveEgg, size: CGFloat) -> some View {
        VStack(spacing: BatwalkSpacing.xs) {
            Text("Your first egg")
                .font(BatwalkFont.caption)
                .multilineTextAlignment(.center)
            if !typeSize.isAccessibilitySize {
                EggSprite(type: egg.type, state: egg.visualState, size: size)
                    .idleFloat()
                    .accessibilityHidden(true)
            }
            if !onboarding.eggHintSeen {
                Text("Walk a little.\nCome back anytime.")
                    .font(BatwalkFont.micro)
                    .foregroundStyle(BatwalkColor.textSecondaryDark)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }.frame(maxWidth: .infinity)
    }

    // MARK: Actions

    private func feed(_ bat: OwnedBat) {
        guard store.state.fruit > 0 else {
            showFruitHelp = true
            return
        }
        let before = Friendship.level(forEXP: bat.friendshipEXP)
        do { try store.mutate { try $0.feed(bat.speciesID) } }
        catch { Haptics.failure(); return }
        let after = Friendship.level(forEXP: store.state.collection[bat.speciesID]?.friendshipEXP ?? 0)
        store.analytics.log(.feedBat, properties: ["species": bat.speciesID])
        fruitToss += 1
        petCount += 1
        if after > before { Haptics.success() } else { Haptics.light() }
        animationRequest = .interaction(.feed, speciesID: bat.speciesID, levelBefore: before, levelAfter: after)
        onboarding.didFeed()
        showFeedback("That was lovely.")
    }

    private func pet(_ bat: OwnedBat) {
        let levelBefore = Friendship.level(forEXP: bat.friendshipEXP)
        do { _ = try store.mutate { try $0.pet(bat.speciesID, dayKey: DayKey.make(.now)) } }
        catch { Haptics.failure(); return }
        let levelAfter = Friendship.level(forEXP: store.state.collection[bat.speciesID]?.friendshipEXP ?? 0)
        if levelAfter > levelBefore { Haptics.success() } else { Haptics.light() }
        petCount += 1
        onboarding.didPet(hasFruit: store.state.fruit > 0)
        showFeedback("Hello, little friend.")
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

    private func showFeedback(_ message: String) {
        guard onboarding.isFirstCompanionGuide else { return }
        feedbackTask?.cancel()
        feedback = message
        feedbackTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            if !Task.isCancelled { feedback = nil }
        }
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

    private func hatch(_ egg: ActiveEgg) -> Bool {
        let isFirst = store.state.history.isEmpty
        // Save the hatch first, then animate: quitting mid-animation never loses the bat.
        guard let result = try? store.mutate({ try $0.hatch(now: .now) }) else {
            Haptics.failure()
            return false
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
        onboarding.didFinishHatchHelp()
        if isFirst { onboarding.didHatchFirstCompanion() }
        deferPickerAfterReveal = isFirst
        hatching = HatchPresentation(result: result, egg: egg.type, startRevealed: false,
                                     isFirstCompanion: isFirst)
        return true
    }
}

/// An explanation requested by tapping empty Feed, rather than a persistent
/// status message that competes with the companion's stage.
private struct FruitHelpView: View {
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BatwalkSpacing.sm) {
                    FruitIcon(size: 28).accessibilityHidden(true)
                    Text("Fruit grows with your walks.")
                        .font(BatwalkFont.caption)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("You can still tap your bat to say hi.")
                        .font(BatwalkFont.micro)
                        .foregroundStyle(BatwalkColor.textSecondaryDark)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }.padding(.horizontal, BatwalkSpacing.sm)
            }
            .navigationTitle("Fruit")
            .watchPageBackground()
        }
    }
}

/// A quick choice on the wrist; pool explanations live on iPhone.
struct EggPickerView: View {
    @Environment(GameStore.self) private var store
    @Environment(WatchOnboarding.self) private var onboarding
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
                                    Text(stepLabel(for: type))
                                        .font(BatwalkFont.micro).monospacedDigit()
                                        .foregroundStyle(BatwalkColor.textSecondaryDark)
                                }
                                Spacer(minLength: 0)
                            }
                            .foregroundStyle(BatwalkColor.cloud)
                            .frame(minHeight: 44)
                        }
                        .buttonStyle(.plain)
                        .accessibilityHint("Start this egg. \(stepLabel(for: type)) to hatch.")
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
            try store.mutate { try $0.startEgg(type, seed: UInt64.random(in: .min ... .max), now: .now, tuning: store.tuning) }
            onboarding.didChooseEgg()
            dismiss()
        } catch { Haptics.failure() }
    }

    private func stepLabel(for type: EggType) -> String {
        let steps = store.tuning.targetSteps(for: type)
        return steps == 1 ? "1 step" : "\(steps.formatted()) steps"
    }
}
