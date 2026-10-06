import SwiftUI
import BatwalkCore

/// Basic History — hatch milestones and simple activity history (PRD §2.5).
/// Shows game events only; raw Health history is never stored or displayed.
struct HistoryView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        NavigationStack {
            List {
                Section {
                    LabeledContent("Bats found", value: "\(store.state.collection.count) / \(Roster.all.count)")
                    LabeledContent("Shiny bats", value: "\(store.state.collection.values.filter(\.hasShiny).count)")
                    LabeledContent("Eggs hatched", value: "\(store.state.history.count)")
                    LabeledContent("Steps walked with Batwalk", value: store.state.lifetimeCreditedSteps.formatted())
                }
                Section("Hatches") {
                    if store.state.history.isEmpty {
                        Text("No hatches yet.").foregroundStyle(.secondary)
                    }
                    ForEach(Array(store.state.history.reversed().enumerated()), id: \.offset) { _, record in
                        HStack {
                            BatSprite(speciesID: record.speciesID, shiny: record.isShiny, mood: .awake, size: 36)
                            VStack(alignment: .leading) {
                                Text(Roster.species(record.speciesID)?.name ?? record.speciesID)
                                    + Text(record.isShiny ? " ✨" : "")
                                Text("\(record.eggType.displayName) · \(label(record.outcome))")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(record.hatchedAt.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .navigationTitle("History")
        }
    }

    private func label(_ outcome: HatchOutcome) -> String {
        switch outcome {
        case .newSpecies: return "New!"
        case .newShiny: return "New Shiny!"
        case .duplicate: return "Friendship up"
        }
    }
}

/// Purchase / Restore Purchase (PRD §2.5, §2.10).
struct UnlockView: View {
    @Environment(PurchaseManager.self) private var purchases

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Batwalk Full Unlock").font(.title2.bold())
                        Text("All 20 bats, every egg, Rare, Legendary and Shiny bats, and full Friendship progression. One-time purchase — no subscriptions, no shortcuts, ever.")
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 4)
                }
                Section {
                    if purchases.isUnlocked {
                        Label("Unlocked — thank you!", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(.green)
                    } else {
                        Button {
                            Task { await purchases.purchase() }
                        } label: {
                            Text("Unlock for \(purchases.product?.displayPrice ?? "$1.99")")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(purchases.product == nil || purchases.isBusy)
                    }
                    Button("Restore Purchase") {
                        Task { await purchases.restore() }
                    }
                    .disabled(purchases.isBusy)
                }
                if let error = purchases.lastError {
                    Section { Text(error).font(.caption).foregroundStyle(.red) }
                }
            }
            .navigationTitle("Unlock")
        }
    }
}
