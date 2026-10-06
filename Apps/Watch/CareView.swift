import SwiftUI
import WatchKit
import BatwalkCore

/// Feed, pet, wake (PRD §2.4, §2.8). Short, expressive reactions; nothing here can ever punish.
struct CareView: View {
    @Environment(GameStore.self) private var store

    /// Temporary reaction mood; falls back to the time-of-day resting mood.
    @State private var reaction: BatMood?
    @State private var reactionTask: Task<Void, Never>?

    var body: some View {
        if let companion = store.state.companion {
            TimelineView(.everyMinute) { context in
                let time = TimeOfDay.at(context.date)
                VStack(spacing: 6) {
                    BatSprite(
                        speciesID: companion.speciesID,
                        shiny: companion.showsShiny,
                        mood: reaction ?? BatMood.resting(at: time),
                        size: 84
                    )
                    .onTapGesture { pet(companion) }

                    FriendshipBar(exp: companion.friendshipEXP)

                    HStack {
                        Button {
                            feed(companion)
                        } label: {
                            Label("\(store.state.fruit)", systemImage: "leaf.fill")
                        }
                        .disabled(store.state.fruit == 0)

                        if time != .night {
                            Button {
                                react(.awake, haptic: .click)
                            } label: {
                                Image(systemName: "sun.max.fill")
                            }
                            .accessibilityLabel("Wake")
                        }
                    }
                    .controlSize(.small)
                }
            }
        }
    }

    private func pet(_ bat: OwnedBat) {
        _ = try? store.mutate { try $0.pet(bat.speciesID, dayKey: DayKey.make(.now)) }
        react(.happy, haptic: .click)
    }

    private func feed(_ bat: OwnedBat) {
        do {
            try store.mutate { try $0.feed(bat.speciesID) }
            store.analytics.log(.feedBat, properties: ["species": bat.speciesID])
            react(.eating, haptic: .success)
        } catch {
            WKInterfaceDevice.current().play(.failure)
        }
    }

    private func react(_ mood: BatMood, haptic: WKHapticType) {
        WKInterfaceDevice.current().play(haptic)
        reaction = mood
        reactionTask?.cancel()
        reactionTask = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { reaction = nil }
        }
    }
}

struct FriendshipBar: View {
    let exp: Int

    var body: some View {
        let level = Friendship.level(forEXP: exp)
        VStack(spacing: 2) {
            Text("Friendship Lv.\(level)").font(.caption2)
            ProgressView(value: Friendship.progressToNext(exp: exp))
                .tint(.pink)
        }
    }
}
