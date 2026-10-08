import SwiftUI
import BatwalkCore

/// Collection (board: Watch › 4. Collection): 3-column grid, glowing unlocked
/// tiles, dark locked tiles, ♥ on the companion. Newly found bats play the unlock reveal.
struct CollectionPage: View {
    @Environment(GameStore.self) private var store
    /// Species the player has already seen in the grid (UI memory, not game state).
    @AppStorage("batwalk.seenBats") private var seenRaw = ""
    @AppStorage("batwalk.seenBatsInitialized") private var seenInitialized = false
    @State private var newIDs: Set<String> = []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 3)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 6) {
                    HStack {
                        Spacer()
                        Text("\(store.state.collection.count)/\(Roster.all.count)")
                            .font(BatwalkFont.caption)
                            .monospacedDigit()
                            .foregroundStyle(BatwalkColor.textSecondaryDark)
                            .padding(.trailing, 10)
                    }
                    LazyVGrid(columns: columns, spacing: 6) {
                        ForEach(Roster.all) { species in
                            if let bat = store.state.collection[species.id] {
                                NavigationLink(value: species.id) {
                                    BatCollectionTile(bat: bat,
                                                      isCompanion: store.state.companionID == species.id,
                                                      isNew: newIDs.contains(species.id))
                                }
                                .buttonStyle(PressableStyle())
                            } else {
                                LockedBatTile()
                            }
                        }
                    }
                }
                .padding(.horizontal, 2)
                .batwalkAppear()
            }
            .navigationTitle("Bats")
            .navigationDestination(for: String.self) { BatDetailView(speciesID: $0) }
            .watchPageBackground()
        }
        .onAppear(perform: markNewBats)
    }

    private func markNewBats() {
        let owned = Set(store.state.collection.keys)
        if store.isDemo {
            newIDs = DemoMode.newlyUnlocked
            return
        }
        // First run on this device (update, restore): everything already owned is "seen".
        guard seenInitialized else {
            seenRaw = owned.sorted().joined(separator: ",")
            seenInitialized = true
            return
        }
        let seen = Set(seenRaw.split(separator: ",").map(String.init))
        newIDs = owned.subtracting(seen)
        guard !newIDs.isEmpty else { return }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(900))
            seenRaw = owned.sorted().joined(separator: ",")
        }
    }
}

/// Bat detail on the Watch: companion, nickname, Shiny toggle, Friendship.
struct BatDetailView: View {
    @Environment(GameStore.self) private var store
    let speciesID: String

    @State private var nameDraft = ""

    var body: some View {
        ScrollView {
            if let bat = store.state.collection[speciesID], let species = bat.species {
                VStack(spacing: 6) {
                    BatHeroView(speciesID: speciesID, shiny: bat.showsShiny, mood: .awake, size: 76)
                    Text(bat.displayName).font(BatwalkFont.headline).foregroundStyle(.white)
                    if bat.nickname != nil {
                        Text(species.name).font(BatwalkFont.micro).foregroundStyle(BatwalkColor.textSecondaryDark)
                    }
                    HStack(spacing: 4) {
                        RarityChip(rarity: species.rarity)
                        if bat.hasShiny { VariantChip(shiny: bat.showsShiny) }
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Friendship Lv. \(Friendship.level(forEXP: bat.friendshipEXP))")
                            .font(BatwalkFont.caption)
                            .foregroundStyle(BatwalkColor.pinkAccent)
                        FriendshipProgressView(exp: bat.friendshipEXP)
                    }
                    .batwalkGlassCard(padding: 8, radius: 14)

                    if store.state.companionID == speciesID {
                        Label("Current Companion", systemImage: "heart.fill")
                            .font(BatwalkFont.caption)
                            .foregroundStyle(BatwalkColor.pinkAccent)
                            .padding(.vertical, 4)
                    } else {
                        Button("Make Companion") {
                            _ = try? store.mutate { try $0.setCompanion(speciesID) }
                            store.analytics.log(.companionChanged, properties: ["species": speciesID])
                            Haptics.light()
                        }
                        .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 36))
                    }

                    TextField("Nickname", text: $nameDraft)
                        .onSubmit { _ = try? store.mutate { try $0.rename(speciesID, to: nameDraft) } }

                    if bat.hasShiny && bat.hasNormal {
                        Toggle("Show Shiny", isOn: Binding(
                            get: { bat.showsShiny },
                            set: { value in _ = try? store.mutate { try $0.setShowsShiny(speciesID, value) } }
                        ))
                        .font(BatwalkFont.caption)
                        .batwalkGlassCard(padding: 8, radius: 14)
                    }
                }
                .padding(.horizontal, BatwalkSpacing.xs)
                .onAppear { nameDraft = bat.nickname ?? "" }
            }
        }
        .navigationTitle(Roster.species(speciesID)?.name ?? "Bat")
        .watchPageBackground()
    }
}
