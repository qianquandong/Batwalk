import SwiftUI
import WatchKit
import BatwalkCore

/// Where most time is spent: the current bat or the current egg (PRD §2.4).
/// The bat/egg dominates; numbers stay secondary (PRD §3.4).
struct HomeView: View {
    @Environment(GameStore.self) private var store

    @State private var reveal: RevealItem?
    @State private var showEggPicker = false

    var body: some View {
        TimelineView(.everyMinute) { context in
            let time = TimeOfDay.at(context.date)
            ZStack {
                SkyBackground(time: time)
                content(time: time)
            }
        }
        .sheet(item: $reveal, onDismiss: {
            // Straight into choosing the next egg — keeps the loop moving (PRD §2.1).
            if store.state.egg == nil { showEggPicker = true }
        }) { item in
            HatchRevealView(result: item.result) { reveal = nil }
        }
        .sheet(isPresented: $showEggPicker) {
            EggPickerView()
        }
    }

    @ViewBuilder
    private func content(time: TimeOfDay) -> some View {
        let state = store.state
        if let egg = state.egg, egg.isReady || state.companion == nil {
            // Before the first hatch, or when ready: the egg is the star.
            VStack(spacing: 4) {
                EggSprite(type: egg.type, state: egg.visualState, size: 110)
                    .onTapGesture { if egg.isReady { hatch() } }
                if egg.isReady {
                    Text("Tap to hatch").font(.footnote.bold())
                } else {
                    Text("\(egg.stepsRemaining.formatted()) steps to go")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        } else if let companion = state.companion {
            VStack(spacing: 2) {
                BatSprite(
                    speciesID: companion.speciesID,
                    shiny: companion.showsShiny,
                    mood: BatMood.resting(at: time),
                    size: 110
                )
                Text(companion.displayName).font(.headline)
                if let egg = state.egg {
                    EggChip(egg: egg)
                } else {
                    Button("Pick an egg") { showEggPicker = true }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.mini)
                }
            }
        }
    }

    private func hatch() {
        do {
            let isFirst = store.state.history.isEmpty
            let result = try store.mutate { try $0.hatch(now: .now) }
            WKInterfaceDevice.current().play(result.record.outcome == .duplicate ? .click : .success)
            store.analytics.log(isFirst ? .firstHatch : .batCollected, properties: [
                "species": result.record.speciesID,
                "rarity": Roster.species(result.record.speciesID)?.rarity.rawValue ?? "",
                "shiny": result.record.isShiny ? "true" : "false",
            ])
            if result.record.outcome == .duplicate {
                store.analytics.log(.duplicateFriendship, properties: ["species": result.record.speciesID])
            }
            reveal = RevealItem(result: result)
        } catch {
            WKInterfaceDevice.current().play(.failure)
        }
    }
}

struct RevealItem: Identifiable {
    let id = UUID()
    let result: HatchResult
}

private struct EggChip: View {
    let egg: ActiveEgg
    var body: some View {
        HStack(spacing: 4) {
            Gauge(value: egg.progress) { EmptyView() }
                .gaugeStyle(.accessoryCircularCapacity)
                .scaleEffect(0.45)
                .frame(width: 22, height: 22)
            Text("\(egg.stepsRemaining.formatted()) to hatch")
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

/// High-value emotional moment (PRD §3.2). Rare/Legendary get a bigger reveal.
struct HatchRevealView: View {
    let result: HatchResult
    let onDone: () -> Void

    @State private var revealed = false

    private var species: Species? { Roster.species(result.record.speciesID) }

    var body: some View {
        ScrollView {
            VStack(spacing: 6) {
                ZStack {
                    if (species?.rarity ?? .common) >= .rare || result.record.isShiny {
                        Circle()
                            .fill(RadialGradient(colors: [.yellow.opacity(0.6), .clear], center: .center, startRadius: 4, endRadius: 70))
                            .scaleEffect(revealed ? 1.2 : 0.2)
                    }
                    BatSprite(speciesID: result.record.speciesID, shiny: result.record.isShiny, mood: .happy, size: 96)
                        .scaleEffect(revealed ? 1 : 0.1)
                        .opacity(revealed ? 1 : 0)
                }
                .frame(height: 110)

                Text(species?.name ?? "New bat").font(.headline)
                Text(subtitle).font(.caption2).foregroundStyle(.secondary).multilineTextAlignment(.center)

                Button("Yay!", action: onDone).padding(.top, 4)
            }
        }
        .onAppear {
            // Hatch animation target: 2–4 s (PRD §4.7).
            withAnimation(.spring(response: 0.9, dampingFraction: 0.6).delay(0.4)) { revealed = true }
        }
    }

    private var subtitle: String {
        let rarity = species?.rarity.displayName ?? ""
        switch result.record.outcome {
        case .newSpecies: return result.record.isShiny ? "Shiny \(rarity)! A new friend." : "\(rarity) · A new friend!"
        case .newShiny: return "A Shiny one! ✨"
        case .duplicate: return "Old friend! +\(result.friendshipGained) Friendship"
        }
    }
}

struct EggPickerView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        List {
            Section("Choose your next egg") {
                ForEach(EggType.allCases.filter(\.isPickable), id: \.self) { type in
                    let available = store.state.pickableEggs.contains(type)
                    Button {
                        start(type)
                    } label: {
                        HStack {
                            EggSprite(type: type, state: .calm, size: 28)
                            VStack(alignment: .leading) {
                                Text(type.displayName)
                                Text(available ? "\(type.targetSteps.formatted()) steps" : "Full unlock")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .disabled(!available)
                }
            }
        }
    }

    private func start(_ type: EggType) {
        do {
            try store.mutate { try $0.startEgg(type, seed: UInt64.random(in: .min ... .max), now: .now) }
            dismiss()
        } catch {
            WKInterfaceDevice.current().play(.failure)
        }
    }
}

/// Day = soft sky, Dusk = sunset, Night = deep blue with stars (PRD §2.3).
struct SkyBackground: View {
    let time: TimeOfDay

    var body: some View {
        LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
            .ignoresSafeArea()
    }

    private var colors: [Color] {
        switch time {
        case .day: return [Color(red: 0.25, green: 0.33, blue: 0.5), Color(red: 0.12, green: 0.16, blue: 0.25)]
        case .dusk: return [Color(red: 0.55, green: 0.3, blue: 0.45), Color(red: 0.15, green: 0.1, blue: 0.25)]
        case .night: return [Color(red: 0.05, green: 0.06, blue: 0.18), .black]
        }
    }
}
