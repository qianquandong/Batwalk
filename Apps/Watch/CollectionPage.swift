import SwiftUI
import BatwalkCore

/// Collection (board: Watch › 4. Collection): 3-column grid, glowing unlocked
/// tiles, dark locked tiles, ♥ on the companion. Newly found bats play the unlock
/// reveal. Above the grid: the "met every free bat" card and the Moon Dust row.
struct CollectionPage: View {
    @Environment(GameStore.self) private var store
    /// Species the player has already seen in the grid (UI memory, not game state).
    @AppStorage("batwalk.seenBats") private var seenRaw = ""
    @AppStorage("batwalk.seenBatsInitialized") private var seenInitialized = false
    @State private var newIDs: Set<String> = []
    @State private var showUnlock = false
    @State private var calling: HatchPresentation?

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
                    moonDustRow
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
        .sheet(isPresented: $showUnlock) { WatchUnlockView() }
        .fullScreenCover(item: $calling) { presentation in
            HatchSequenceView(presentation: presentation) { calling = nil }
        }
    }

    /// Duplicates of a max-Friendship bat pay Moon Dust; enough dust calls a bat the
    /// player has not met. Hidden until dust is possible, so it never clutters a new game.
    @ViewBuilder
    private var moonDustRow: some View {
        let cost = Tuning.default.moonDustForNewBat
        let anyMaxed = store.state.collection.values.contains { Friendship.level(forEXP: $0.friendshipEXP) >= Friendship.maxLevel }
        if store.state.moonDust > 0 || anyMaxed {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkle").foregroundStyle(BatwalkColor.rarityShiny)
                    Text("Moon Dust").font(BatwalkFont.caption)
                    Spacer(minLength: 4)
                    Text("\(store.state.moonDust) / \(cost)").font(BatwalkFont.caption).monospacedDigit()
                }
                if store.state.canCallNewBat() {
                    Button("Call a new bat") { callNewBat() }
                        .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 34))
                } else if store.state.moonDust >= cost, !store.state.isUnlocked {
                    Button("Nothing new to call — see the full collection") { showUnlock = true }
                        .font(BatwalkFont.micro)
                } else if store.state.moonDust >= cost {
                    Text("You've met every bat. Dust will matter again when new bats arrive.")
                        .font(BatwalkFont.micro).foregroundStyle(BatwalkColor.textSecondaryDark)
                } else {
                    Text("More about Moon Dust on iPhone.")
                        .font(BatwalkFont.micro).foregroundStyle(BatwalkColor.textSecondaryDark)
                }
            }
            .foregroundStyle(.white)
            .batwalkGlassCard(padding: 8, radius: 14)
            .accessibilityElement(children: .combine)
        }
    }

    private func callNewBat() {
        guard let result = try? store.mutate({ try $0.callNewBat(seed: UInt64.random(in: .min ... .max), now: .now) }) else {
            Haptics.failure()
            return
        }
        store.analytics.log(.batCollected, properties: [
            "species": result.record.speciesID,
            "rarity": Roster.species(result.record.speciesID)?.rarity.rawValue ?? "",
            "shiny": "false",
            "source": "moon-dust",
        ])
        calling = HatchPresentation(result: result, egg: result.record.eggType, startRevealed: true)
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
                    BatHeroView(speciesID: speciesID, shiny: bat.showsShiny, mood: .awake, size: 76,
                                friendshipEXP: bat.friendshipEXP, showsKeepsake: false)
                    Text(bat.displayName).font(BatwalkFont.headline).foregroundStyle(.white)
                    if bat.nickname != nil {
                        Text(species.name).font(BatwalkFont.micro).foregroundStyle(BatwalkColor.textSecondaryDark)
                    }
                    HStack(spacing: 4) {
                        RarityChip(rarity: species.rarity)
                        if bat.hasShiny { VariantChip(shiny: bat.showsShiny) }
                    }

                    if store.state.companionID == speciesID {
                        Label("Current Companion", systemImage: "heart.fill")
                            .font(BatwalkFont.caption)
                            .foregroundStyle(BatwalkColor.rose)
                            .padding(.vertical, 4)
                    } else {
                        Button("Make Companion") {
                            do { try store.mutate { try $0.setCompanion(speciesID) } } catch { Haptics.failure(); return }
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
