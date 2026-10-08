import SwiftUI
import BatwalkCore

/// Batpedia (board: iPhone › 1. Batpedia Grid): Normal | Shiny, 3-column grid,
/// unlocked cards open Bat Detail.
struct BatpediaView: View {
    @Environment(GameStore.self) private var store

    private enum Variant: Hashable { case normal, shiny }

    @State private var variant: Variant = .normal
    @State private var path: [String] = DemoMode.detailSpecies.map { [$0] } ?? []

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 3)

    var body: some View {
        NavigationStack(path: $path) {
            ScrollView {
                VStack(alignment: .leading, spacing: BatwalkSpacing.lg) {
                    PhoneHeader(title: "Batpedia · \(foundCount)/\(Roster.all.count)")
                    SegmentedPill(options: [(Variant.normal, "Normal"), (Variant.shiny, "Shiny")], selection: $variant)

                    if !store.state.hasStarted {
                        PhoneEmptyState()
                    }

                    LazyVGrid(columns: columns, spacing: 12) {
                        ForEach(Array(Roster.all.enumerated()), id: \.element.id) { index, species in
                            Group {
                                if isOwned(species.id) {
                                    NavigationLink(value: species.id) {
                                        BatCard(species: species,
                                                shiny: variant == .shiny,
                                                isCompanion: store.state.companionID == species.id)
                                    }
                                    .buttonStyle(PressableStyle())
                                } else {
                                    LockedBatCard(number: species.number)
                                }
                            }
                            .staggeredAppear(index: index)
                        }
                    }
                }
                .padding(BatwalkSpacing.lg)
            }
            .background(BatwalkColor.lightBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .navigationDestination(for: String.self) { BatDetailPage(speciesID: $0) }
        }
    }

    private var foundCount: Int {
        store.state.collection.values.filter { variant == .shiny ? $0.hasShiny : $0.hasNormal }.count
    }

    private func isOwned(_ id: String) -> Bool {
        guard let bat = store.state.collection[id] else { return false }
        return variant == .shiny ? bat.hasShiny : bat.hasNormal
    }
}

/// Bat Detail (board: iPhone › 2. Bat Detail): atmospheric hero, chips, info
/// cards, Set as Companion (sent to the Watch, which owns the save).
struct BatDetailPage: View {
    @Environment(GameStore.self) private var store
    let speciesID: String

    @State private var sendResult: PhoneSync.SendResult?

    var body: some View {
        ScrollView {
            if let bat = store.state.collection[speciesID], let species = bat.species {
                VStack(spacing: 0) {
                    hero(bat: bat, species: species)
                    VStack(spacing: BatwalkSpacing.md) {
                        VStack(spacing: 0) {
                            BatInfoRow(title: "Friendship Level",
                                       value: "Lv. \(Friendship.level(forEXP: bat.friendshipEXP))") {
                                Image(systemName: "heart.fill").foregroundStyle(BatwalkColor.pinkAccent)
                            } detail: {
                                FriendshipProgressView(exp: bat.friendshipEXP, dark: false)
                            }
                            if let fruit = species.favoriteFruit {
                                Divider()
                                BatInfoRow(title: "Favorite Fruit", value: fruit) { FruitIcon(size: 18) }
                            }
                            if let first = store.state.history.first(where: { $0.speciesID == speciesID }) {
                                Divider()
                                BatInfoRow(title: "Hatch Source", value: first.eggType.displayName) {
                                    EggIcon(type: first.eggType, size: 20)
                                }
                            }
                            Divider()
                            BatInfoRow(title: "Hatched", value: bat.firstHatchedAt.formatted(date: .abbreviated, time: .omitted)) {
                                Image(systemName: "calendar").foregroundStyle(BatwalkColor.purple)
                            }
                            if bat.hatchCount > 1 {
                                Divider()
                                BatInfoRow(title: "Times Hatched", value: "\(bat.hatchCount)") {
                                    Image(systemName: "sparkles").foregroundStyle(BatwalkColor.purple)
                                }
                            }
                        }
                        .batwalkLightCard(padding: 14, radius: 22)

                        companionButton(bat)
                    }
                    .padding(BatwalkSpacing.lg)
                    .background(
                        UnevenRoundedRectangle(topLeadingRadius: 28, topTrailingRadius: 28, style: .continuous)
                            .fill(BatwalkColor.lightBackground)
                    )
                    .offset(y: -24)
                }
            }
        }
        .background(BatwalkColor.lightBackground)
        .ignoresSafeArea(edges: .top)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarColorScheme(.dark, for: .navigationBar)
        .onChange(of: store.state.companionID) { _, _ in sendResult = nil }
    }

    private func hero(bat: OwnedBat, species: Species) -> some View {
        ZStack(alignment: .bottomLeading) {
            NightSkyBackground(time: .night, scenery: true)
            BatHeroView(speciesID: speciesID, shiny: bat.showsShiny, mood: .happy, size: 200)
                .frame(maxWidth: .infinity)
                .padding(.bottom, 92)
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Text(bat.displayName)
                        .font(BatwalkFont.rounded(.largeTitle, weight: .bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    if store.state.companionID == speciesID {
                        Image(systemName: "heart.fill").foregroundStyle(BatwalkColor.pinkAccent)
                    }
                }
                HStack(spacing: 6) {
                    VariantChip(shiny: bat.showsShiny)
                    RarityChip(rarity: species.rarity)
                }
            }
            .padding(.horizontal, BatwalkSpacing.lg)
            .padding(.bottom, 40)
        }
        .frame(height: 400)
    }

    @ViewBuilder
    private func companionButton(_ bat: OwnedBat) -> some View {
        if store.state.companionID == speciesID {
            Label("Current Companion", systemImage: "checkmark.circle.fill")
                .font(BatwalkFont.headline)
                .foregroundStyle(BatwalkColor.purple)
                .frame(maxWidth: .infinity, minHeight: 50)
                .background(Capsule().fill(BatwalkColor.lightTint))
        } else {
            VStack(spacing: 6) {
                Button {
                    sendResult = store.isDemo ? .sent : PhoneSync.shared.send(command: [PhoneSync.setCompanionKey: speciesID])
                    if sendResult == .sent { Haptics.light() } else { Haptics.failure() }
                } label: {
                    Label(sendResult == .sent ? "Sent to your Watch" : "Set as Companion",
                          systemImage: sendResult == .sent ? "applewatch" : "heart.fill")
                }
                .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 50))
                .disabled(sendResult == .sent)

                switch sendResult {
                case .noWatchApp:
                    Text("Install Batwalk on your Apple Watch to change companions.")
                case .unavailable:
                    Text("Your Apple Watch isn't reachable right now. Try again in a moment.")
                case .sent:
                    Text("\(bat.species?.name ?? "This bat") will greet you on your wrist.")
                case nil:
                    EmptyView()
                }
            }
            .font(BatwalkFont.caption)
            .foregroundStyle(BatwalkColor.textSecondaryLight)
            .multilineTextAlignment(.center)
        }
    }
}
