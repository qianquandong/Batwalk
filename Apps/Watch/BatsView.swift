import SwiftUI
import BatwalkCore

/// Compact collection grid + current companion selector (PRD §2.4).
struct BatsView: View {
    @Environment(GameStore.self) private var store

    private let columns = [GridItem(.adaptive(minimum: 44), spacing: 6)]

    var body: some View {
        NavigationStack {
            ScrollView {
                Text("\(store.state.collection.count)/\(Roster.all.count) bats")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(Roster.all) { species in
                        if let owned = store.state.collection[species.id] {
                            NavigationLink(value: species.id) {
                                BatSprite(speciesID: species.id, shiny: owned.showsShiny, mood: .awake, size: 40)
                                    .overlay(alignment: .topTrailing) {
                                        if store.state.companionID == species.id {
                                            Image(systemName: "heart.fill").font(.system(size: 9)).foregroundStyle(.pink)
                                        }
                                    }
                            }
                            .buttonStyle(.plain)
                        } else {
                            Text("?")
                                .font(.title3)
                                .frame(width: 40, height: 40)
                                .background(Circle().fill(.white.opacity(0.08)))
                                .accessibilityLabel("Not found yet")
                        }
                    }
                }
            }
            .navigationTitle("Bats")
            .navigationDestination(for: String.self) { id in
                BatDetailView(speciesID: id)
            }
        }
    }
}

struct BatDetailView: View {
    @Environment(GameStore.self) private var store
    let speciesID: String

    @State private var nameDraft = ""

    var body: some View {
        if let bat = store.state.collection[speciesID], let species = bat.species {
            ScrollView {
                VStack(spacing: 6) {
                    BatSprite(speciesID: speciesID, shiny: bat.showsShiny, mood: .awake, size: 80)
                    Text(bat.displayName).font(.headline)
                    if bat.nickname != nil {
                        Text(species.name).font(.caption2).foregroundStyle(.secondary)
                    }
                    Text(species.rarity.displayName).font(.caption2)
                    FriendshipBar(exp: bat.friendshipEXP)

                    if store.state.companionID != speciesID {
                        Button("Make companion") {
                            _ = try? store.mutate { try $0.setCompanion(speciesID) }
                            store.analytics.log(.companionChanged, properties: ["species": speciesID])
                        }
                    }

                    TextField("Name", text: $nameDraft)
                        .onSubmit { _ = try? store.mutate { try $0.rename(speciesID, to: nameDraft) } }

                    if bat.hasShiny && bat.hasNormal {
                        Toggle("Shiny", isOn: Binding(
                            get: { bat.showsShiny },
                            set: { value in _ = try? store.mutate { try $0.setShowsShiny(speciesID, value) } }
                        ))
                    }
                }
            }
            .onAppear { nameDraft = bat.nickname ?? "" }
        }
    }
}
