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
    @State private var settings = false

    private var columns: [GridItem] {
        Array(repeating: GridItem(.flexible(), spacing: 14), count: typeSize.isAccessibilitySize ? 1 : 2)
    }

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        PhoneHeader(title: "Batpedia")
                        Button { searching.toggle() } label: {
                            Image(systemName: "magnifyingglass").font(.title3).frame(width: 44, height: 44)
                        }.accessibilityLabel("Search bats")
                        Button { settings = true } label: {
                            Image(systemName: "gearshape").frame(width: 44, height: 44)
                        }.accessibilityLabel("Settings")
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
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Collection milestones").font(BatwalkFont.headline)
                        ForEach([5, 10, 20, Roster.all.count], id: \.self) { goal in
                            Label("\(goal) bats discovered", systemImage: store.state.collection.count >= goal ? "checkmark.circle.fill" : "circle")
                                .font(BatwalkFont.caption).foregroundStyle(BatwalkColor.accent)
                        }
                    }
                    PhoneSyncStatus()
                }
                .padding(24)
            }
            .background(BatwalkColor.lightBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { BatDetailPage(speciesID: $0) }
            .sheet(isPresented: $settings) { PhoneSettingsView() }
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
    let speciesID: String

    var body: some View {
        ScrollView {
            if let bat = store.state.collection[speciesID], let species = bat.species {
                VStack(spacing: 0) {
                    BatHeroView(speciesID: speciesID, shiny: bat.showsShiny, mood: .awake,
                                size: 160, friendshipEXP: bat.friendshipEXP, showsKeepsake: false)
                        .frame(maxWidth: .infinity).padding(.vertical, 20)
                        .background(NightSkyBackground(time: .night, scenery: true, groundLevel: 0.86))
                        .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
                    VStack(alignment: .leading, spacing: 20) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(String(format: "No. %02d", species.number)).font(BatwalkFont.caption)
                                .foregroundStyle(BatwalkColor.textSecondaryLight)
                            Text(bat.companionTitle).font(BatwalkFont.rounded(.largeTitle, weight: .bold))
                            Text(species.hook).font(BatwalkFont.body)
                                .foregroundStyle(BatwalkColor.textSecondaryLight)
                        }
                        HStack(spacing: 8) {
                            VariantChip(shiny: bat.showsShiny, dark: false)
                            RarityChip(rarity: species.rarity, dark: false)
                        }
                        BatInfoRow(title: "Friendship", value: "Lv. \(Friendship.level(forEXP: bat.friendshipEXP))") {
                            Image(systemName: "heart.fill").foregroundStyle(BatwalkColor.rose)
                        } detail: {
                            FriendshipProgressView(exp: bat.friendshipEXP, dark: false)
                        }
                        Divider()
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
                            BatInfoRow(title: "Hatch source", value: first.eggType.displayName) {
                                EggIcon(type: first.eggType, size: 24)
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
        .safeAreaInset(edge: .bottom) {
            if store.state.collection[speciesID] != nil {
                VStack(spacing: 10) {
                    if store.state.companionID != speciesID || store.companionHandoff.isWaiting {
                        CurrentCompanionRow(compact: true)
                    }
                    CompanionChangeControl(speciesID: speciesID)
                }
                    .padding(.horizontal, 24).padding(.vertical, 12)
                    .background(BatwalkColor.lightBackground)
            }
        }
        .navigationTitle("Batpedia")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
        .toolbar(.hidden, for: .tabBar)
        .toolbarBackground(BatwalkColor.lightBackground, for: .navigationBar)
        .toolbarBackground(.visible, for: .navigationBar)
        .toolbarColorScheme(.light, for: .navigationBar)
    }
}
