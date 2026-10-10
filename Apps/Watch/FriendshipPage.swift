import SwiftUI
import BatwalkCore

/// Friendship (board: Watch › 3. Friendship): bat, level, pink bar, big Feed button.
/// Feeding: button press → fruit hops in → happy bounce + hearts → bar fills.
/// Nothing on this page can ever punish (PRD §2.8).
struct FriendshipPage: View {
    @Environment(GameStore.self) private var store

    @State private var reaction: BatMood?
    @State private var reactionTask: Task<Void, Never>?
    @State private var bounce = 0
    @State private var hearts = 0
    @State private var fruitToss = 0

    var body: some View {
        NavigationStack {
            ScrollView {
                if let companion = store.state.companion {
                    TimelineView(.everyMinute) { context in
                        let time = DemoMode.timeOfDay(at: context.date)
                        VStack(spacing: 2) {
                            ZStack {
                                BatHeroView(
                                    speciesID: companion.speciesID,
                                    shiny: companion.showsShiny,
                                    mood: reaction ?? BatMood.resting(at: time),
                                    size: 70,
                                    bounceTrigger: bounce,
                                    friendshipEXP: companion.friendshipEXP
                                )
                                HeartBurst(trigger: hearts)
                                FruitToss(trigger: fruitToss)
                            }
                            .frame(height: 60)
                            .contentShape(Rectangle())
                            .onTapGesture { pet(companion) }
                            .accessibilityAddTraits(.isButton)
                            .accessibilityHint(BatMood.resting(at: time) == .awake ? "Pet \(companion.displayName)" : "Wake \(companion.displayName)")

                            Text(companion.displayName)
                                .font(BatwalkFont.headline)
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("Friendship Lv. \(Friendship.level(forEXP: companion.friendshipEXP))")
                                .font(BatwalkFont.caption)
                                .foregroundStyle(BatwalkColor.rose)

                            FriendshipProgressView(exp: companion.friendshipEXP)
                                .padding(.horizontal, BatwalkSpacing.xs)
                                .padding(.top, 2)
                            FeedButton(fruit: store.state.fruit) { feed(companion) }
                            if let reward = Friendship.keepsake(forEXP: companion.friendshipEXP) {
                                Text("Unlocked: \(reward)").font(BatwalkFont.micro).foregroundStyle(BatwalkColor.rose)
                            }
                            if let next = Friendship.nextKeepsake(forEXP: companion.friendshipEXP) {
                                Text("Next: \(next)").font(BatwalkFont.micro).foregroundStyle(BatwalkColor.textSecondaryDark)
                            }

                            if store.state.fruit == 0 {
                                Text("Walk to find fruit")
                                    .font(BatwalkFont.micro)
                                    .foregroundStyle(BatwalkColor.textSecondaryDark)
                            }
                        }
                        .padding(.horizontal, BatwalkSpacing.xs)
                        .batwalkAppear()
                    }
                }
            }
            .navigationTitle("Friendship")
            .watchPageBackground()
        }
    }

    private func pet(_ bat: OwnedBat) {
        let before = Friendship.level(forEXP: bat.friendshipEXP)
        do { _ = try store.mutate { try $0.pet(bat.speciesID, dayKey: DayKey.make(.now)) } }
        catch { Haptics.failure(); return }
        celebrate(levelBefore: before, speciesID: bat.speciesID)
    }

    private func feed(_ bat: OwnedBat) {
        let before = Friendship.level(forEXP: bat.friendshipEXP)
        do {
            try store.mutate { try $0.feed(bat.speciesID) }
            store.analytics.log(.feedBat, properties: ["species": bat.speciesID])
            fruitToss += 1
            reaction = .eating
            Task { @MainActor in
                try? await Task.sleep(for: .milliseconds(420))
                celebrate(levelBefore: before, speciesID: bat.speciesID)
            }
        } catch {
            Haptics.failure()
        }
    }

    private func celebrate(levelBefore: Int, speciesID: String) {
        let after = Friendship.level(forEXP: store.state.collection[speciesID]?.friendshipEXP ?? 0)
        if after > levelBefore { Haptics.success() } else { Haptics.light() }
        bounce += 1
        hearts += 1
        // Tapping a sleeping / drowsy bat wakes it (CARE: feed · pet · wake, PRD §2.4).
        let resting = BatMood.resting(at: DemoMode.timeOfDay(at: .now))
        reaction = (reaction == nil && (resting == .sleeping || resting == .drowsy)) ? .awake : .happy
        reactionTask?.cancel()
        reactionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2.5))
            if !Task.isCancelled { reaction = nil }
        }
    }
}
