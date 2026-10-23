import SwiftUI
import BatwalkCore

struct BatpediaView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    private enum Variant: Hashable { case normal, shiny }
    @State private var variant: Variant = .normal
    @State private var path: [String] = DemoMode.detailSpecies.map { [$0] } ?? []
    @State private var query = ""
    @State private var searching = false

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 10), count: typeSize.isAccessibilitySize ? 1 : 3)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        PhoneHeader(title: "Our little world")
                        // Settings live on the Companion tab only.
                        Button { searching.toggle() } label: {
                            Image(systemName: "magnifyingglass").font(.title3).frame(width: 44, height: 44)
                        }.accessibilityLabel("Search bats")
                    }
                    Text("\(foundCount) / \(Roster.all.count) discovered")
                        .font(BatwalkFont.body).foregroundStyle(BatwalkColor.textSecondaryLight)
                    SegmentedPill(options: [(Variant.normal, "Normal"), (Variant.shiny, "Shiny")], selection: $variant)
                    if searching {
                        TextField("Search discovered bats", text: $query)
                            .textFieldStyle(.roundedBorder).submitLabel(.search)
                    }
                    if !store.state.hasStarted { PhoneEmptyState() }
                    LazyVGrid(columns: columns, spacing: 14) {
                        ForEach(species) { bat in
                            if isOwned(bat.id) {
                                NavigationLink(value: bat.id) {
                                    BatCard(species: bat, shiny: variant == .shiny,
                                            isCompanion: store.state.companionID == bat.id)
                                }.buttonStyle(PressableStyle())
                            } else {
                                LockedBatCard(number: bat.number)
                            }
                        }
                    }
                    if species.isEmpty {
                        Text("No discovered bats match your search.")
                            .font(BatwalkFont.body).foregroundStyle(BatwalkColor.textSecondaryLight)
                    }
                    Text("Every bat has a little personality.")
                        .font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryLight)
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                    PhoneSyncStatus()
                }
                .padding(24)
            }
            .background(BatwalkColor.lightBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationTitle("Collection")
            .navigationDestination(for: String.self) { BatDetailPage(speciesID: $0) }

        }
        .toolbar(path.isEmpty ? .visible : .hidden, for: .tabBar)
    }

    private var foundCount: Int {
        store.state.collection.values.filter { variant == .shiny ? $0.hasShiny : $0.hasNormal }.count
    }
    private var species: [Species] {
        Roster.all.filter {
            !searching || query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            (isOwned($0.id) && ($0.name.localizedCaseInsensitiveContains(query) ||
                              (store.state.collection[$0.id]?.nickname?.localizedCaseInsensitiveContains(query) ?? false)))
        }.sorted {
            if isOwned($0.id) != isOwned($1.id) { return isOwned($0.id) }
            return $0.number < $1.number
        }
    }
    private func isOwned(_ id: String) -> Bool {
        guard let bat = store.state.collection[id] else { return false }
        return variant == .shiny ? bat.hasShiny : bat.hasNormal
    }
}

struct BatDetailPage: View {
    @Environment(GameStore.self) private var store
    @Environment(\.batPageVisible) private var pageVisible
    let speciesID: String
    @State private var shareImage: Image?
    @State private var moment: BatMomentSelection?

    private var bat: OwnedBat? { store.state.collection[speciesID] }
    private var species: Species? { bat?.species }

    var body: some View {
        ScrollView {
            if let bat, let species {
                VStack(spacing: 0) {
                    // Same inset-card hero as the Companion page.
                    BatHeroView(speciesID: speciesID, shiny: bat.showsShiny, mood: .awake,
                                size: 160, friendshipEXP: bat.friendshipEXP, showsKeepsake: false)
                        .environment(\.batPageVisible, pageVisible && moment == nil)
                        .frame(maxWidth: .infinity).padding(.vertical, 20)
                        .background(NightSkyBackground(time: .night, scenery: true, groundLevel: 0.86))
                        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
                        .padding(.horizontal, 16)
                        .padding(.top, 8)
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(format: "No. %02d", species.number)).font(BatwalkFont.caption)
                                .foregroundStyle(BatwalkColor.textSecondaryLight)
                            Text(bat.companionTitle).font(BatwalkFont.rounded(.largeTitle, weight: .bold))
                            Text(species.hook).font(BatwalkFont.body)
                                .foregroundStyle(BatwalkColor.textSecondaryLight)
                        }
                        HStack(spacing: 8) {
                            RarityChip(rarity: species.rarity, dark: false)
                            VariantChip(shiny: bat.showsShiny, dark: false)
                        }
                        // Context for the pinned "Choose for Watch" button below.
                        if store.state.companionID != speciesID { CurrentCompanionRow(compact: true) }
                        BatInfoRow(title: "Friendship", value: "Lv. \(Friendship.level(forEXP: bat.friendshipEXP))") {
                            Image(systemName: "heart.fill").foregroundStyle(BatwalkColor.rose)
                        } detail: {
                            FriendshipProgressView(exp: bat.friendshipEXP, dark: false)
                        }
                        let actions = PilotAnimationCatalog.playableActions(for: speciesID)
                            .filter { $0.tier != .secret && $0.tier != .hatchReveal }
                        if !actions.isEmpty { // no header without anything under it
                            Divider()
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Little moments").font(BatwalkFont.title)
                                Text("These habits happen naturally on your Watch as friendship grows. Tap a discovered moment here to watch it again.")
                                    .font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryLight)
                                ForEach(actions, id: \.id) { action in
                                    let unlocked = Friendship.level(forEXP: bat.friendshipEXP) >= action.unlockLevel
                                    Button {
                                        moment = BatMomentSelection(action: action)
                                    } label: {
                                        Label(unlocked ? action.name : "Lv. \(action.unlockLevel) · \(action.name)",
                                              systemImage: unlocked ? "play.circle" : "lock")
                                            .font(BatwalkFont.body)
                                            .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                                    }
                                    .disabled(!unlocked)
                                    .accessibilityHint(unlocked ? "Watch this little habit" : "Build friendship on your Watch to unlock")
                                }
                            }
                        }
                        if let cousin = species.realLifeCousin {
                            Text("Little habits").font(BatwalkFont.title)
                            Label { Text(cousin).font(BatwalkFont.body) } icon: {
                                Image(systemName: "leaf").foregroundStyle(BatwalkColor.accent)
                            }
                        }
                        if let fruit = species.favoriteFruit {
                            BatInfoRow(title: "Favorite fruit", value: fruit) { FruitIcon(size: 20) } detail: { EmptyView() }
                        }
                        BatInfoRow(title: "First hatched", value: bat.firstHatchedAt.formatted(date: .abbreviated, time: .omitted)) {
                            Image(systemName: "calendar").foregroundStyle(BatwalkColor.accent)
                        } detail: { EmptyView() }
                        if let first = store.state.history.first(where: { $0.speciesID == speciesID }) {
                            BatInfoRow(title: first.source == .moonDust ? "Called with" : "Hatch source",
                                       value: first.source == .moonDust ? "Moon Dust" : first.eggType.displayName) {
                                if first.source == .moonDust {
                                    Image(systemName: "sparkle").foregroundStyle(BatwalkColor.accent)
                                } else {
                                    EggIcon(type: first.eggType, size: 24)
                                }
                            } detail: { EmptyView() }
                        }
                        if bat.hatchCount > 1 {
                            BatInfoRow(title: "Times met", value: "\(bat.hatchCount)") {
                                Image(systemName: "repeat").foregroundStyle(BatwalkColor.accent)
                            } detail: { EmptyView() }
                        }
                        PhoneSyncStatus()
                    }
                    .foregroundStyle(BatwalkColor.textPrimaryLight)
                    .padding(24)
                }
            }
        }
        .background(BatwalkColor.lightBackground.ignoresSafeArea())
        .sheet(item: $moment) { selected in
            if let bat { BatMomentPreview(bat: bat, action: selected.action) }
        }
        .safeAreaInset(edge: .bottom) {
            // One pinned control; the current-companion context sits in the page itself.
            if store.state.collection[speciesID] != nil {
                CompanionChangeControl(speciesID: speciesID)
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(BatwalkColor.lightBackground)
            }
        }
        .navigationTitle(bat?.companionTitle ?? "Batpedia")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(BatwalkColor.lightBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbar {
            if let shareImage, let bat {
                ToolbarItem(placement: .topBarTrailing) {
                    // A bat card with its "real-life cousin" fact — the thing worth sending a friend.
                    ShareLink(item: shareImage, preview: SharePreview(bat.displayName, image: shareImage)) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share \(bat.displayName)")
                }
            }
        }
        .task(id: "\(speciesID)-\(bat?.showsShiny ?? false)-\(bat?.nickname ?? "")") {
            #if os(iOS)
            if let bat, let species { shareImage = BatShareImage.render(bat: bat, species: species) }
            #endif
        }
    }
}
