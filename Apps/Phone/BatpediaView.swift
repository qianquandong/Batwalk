import SwiftUI
import BatwalkCore

/// Collection — owned, missing, Normal/Shiny status (PRD §2.5).
struct BatpediaView: View {
    @Environment(GameStore.self) private var store

    private let columns = [GridItem(.adaptive(minimum: 100), spacing: 12)]

    var body: some View {
        NavigationStack {
            ScrollView {
                if !store.state.hasStarted {
                    ContentUnavailableView(
                        "Your egg is on your wrist",
                        systemImage: "applewatch",
                        description: Text("Open Batwalk on Apple Watch to start. Bats you hatch appear here.")
                    )
                }
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Roster.all) { species in
                        let owned = store.state.collection[species.id]
                        NavigationLink(value: species.id) {
                            BatpediaCell(species: species, owned: owned)
                        }
                        .buttonStyle(.plain)
                        .disabled(owned == nil)
                    }
                }
                .padding()
            }
            .navigationTitle("Batpedia · \(store.state.collection.count)/\(Roster.all.count)")
            .navigationDestination(for: String.self) { id in
                LargeBatView(speciesID: id)
            }
        }
    }
}

private struct BatpediaCell: View {
    let species: Species
    let owned: OwnedBat?

    var body: some View {
        VStack(spacing: 6) {
            if let owned {
                BatSprite(speciesID: species.id, shiny: owned.showsShiny, mood: .awake, size: 72)
            } else {
                Image(systemName: "questionmark")
                    .font(.title)
                    .frame(width: 72, height: 72)
                    .foregroundStyle(.secondary)
            }
            Text(owned == nil ? "#\(species.number)" : species.name)
                .font(.caption.bold())
                .lineLimit(1)
            HStack(spacing: 6) {
                VariantCheck(label: "Normal", owned: owned?.hasNormal ?? false)
                VariantCheck(label: "Shiny", owned: owned?.hasShiny ?? false)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity)
        .background(RoundedRectangle(cornerRadius: 14).fill(.quaternary))
    }
}

private struct VariantCheck: View {
    let label: String
    let owned: Bool
    var body: some View {
        Label(label, systemImage: owned ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 9))
            .foregroundStyle(owned ? HierarchicalShapeStyle.primary : HierarchicalShapeStyle.tertiary)
            .labelStyle(.titleAndIcon)
    }
}

/// Large View — presentation-quality bat view for screenshots (PRD §2.5).
struct LargeBatView: View {
    @Environment(GameStore.self) private var store
    let speciesID: String

    var body: some View {
        if let bat = store.state.collection[speciesID], let species = bat.species {
            ScrollView {
                VStack(spacing: 16) {
                    BatSprite(speciesID: speciesID, shiny: bat.showsShiny, mood: .happy, size: 260)
                        .padding(.top, 24)
                    Text(bat.displayName).font(.largeTitle.bold())
                    if bat.nickname != nil {
                        Text(species.name).foregroundStyle(.secondary)
                    }
                    Text("\(species.rarity.displayName) · #\(species.number)")
                        .font(.subheadline)
                    Text(species.hook).multilineTextAlignment(.center).foregroundStyle(.secondary)

                    GroupBox("Friendship") {
                        VStack(alignment: .leading) {
                            Text("Lv.\(Friendship.level(forEXP: bat.friendshipEXP)) · \(bat.friendshipEXP) EXP")
                            ProgressView(value: Friendship.progressToNext(exp: bat.friendshipEXP)).tint(.pink)
                        }
                    }
                    GroupBox("History") {
                        VStack(alignment: .leading) {
                            Text("First hatched \(bat.firstHatchedAt.formatted(date: .abbreviated, time: .omitted))")
                            Text("Hatched \(bat.hatchCount) time\(bat.hatchCount == 1 ? "" : "s")")
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .padding()
            }
            .background(LinearGradient(colors: [Color(red: 0.05, green: 0.06, blue: 0.18), .black],
                                       startPoint: .top, endPoint: .bottom).ignoresSafeArea())
            .preferredColorScheme(.dark)
        }
    }
}
