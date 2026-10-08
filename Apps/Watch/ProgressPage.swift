import SwiftUI
import BatwalkCore

/// Progress (board: Watch › 2. Progress): glowing ring, steps to hatch, two stat rows.
/// Health troubleshooting lives in Settings, not here.
struct ProgressPage: View {
    @Environment(GameStore.self) private var store
    @Binding var page: Int

    @State private var showEggPicker = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BatwalkSpacing.sm) {
                    if let egg = store.state.egg {
                        BatwalkProgressRing(progress: egg.progress, lineWidth: 9) {
                            VStack(spacing: 2) {
                                Text("\(Int((egg.progress * 100).rounded(.down)))%")
                                    .font(BatwalkFont.rounded(.title2, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                                EggIcon(type: egg.type, size: 18)
                            }
                        }
                        .frame(width: 98, height: 98)
                        .padding(.top, BatwalkSpacing.xs)

                        Text(egg.isReady ? "Ready to hatch!" : "\(egg.stepsRemaining.formatted()) steps to hatch")
                            .font(BatwalkFont.rounded(.footnote, weight: .semibold))
                            .monospacedDigit()
                            .foregroundStyle(.white)
                            .padding(.bottom, 2)
                    } else {
                        EggIcon(size: 40).padding(.top, BatwalkSpacing.sm)
                        Text("No egg yet").font(BatwalkFont.headline).foregroundStyle(.white)
                        Button("Pick an egg") { showEggPicker = true }
                            .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 36))
                    }

                    BatwalkStatRow(title: "Today", value: todaySteps.formatted()) {
                        Image(systemName: "figure.walk")
                            .font(.system(size: 13, weight: .semibold))
                            .foregroundStyle(BatwalkColor.softLavender)
                    }

                    if store.state.companion != nil {
                        Button { withAnimation(BatwalkMotion.page) { page = 2 } } label: {
                            BatwalkStatRow(title: "Fruit", value: "\(store.state.fruit)", chevron: true) {
                                FruitIcon(size: 16)
                            }
                        }
                        .buttonStyle(PressableStyle())
                    } else {
                        BatwalkStatRow(title: "Fruit", value: "\(store.state.fruit)") { FruitIcon(size: 16) }
                    }

                    if store.state.bankedSteps > 0 {
                        BatwalkStatRow(title: "Saved for next egg", value: store.state.bankedSteps.formatted()) {
                            EggIcon(size: 16)
                        }
                    }
                }
                .padding(.horizontal, BatwalkSpacing.xs)
                .batwalkAppear()
            }
            .navigationTitle("Progress")
            .watchPageBackground()
        }
        .sheet(isPresented: $showEggPicker) { EggPickerView() }
    }

    private var todaySteps: Int {
        let ledger = store.state.ledger
        return ledger.dayKey == DayKey.make(.now) ? ledger.lastDailyTotal : 0
    }
}
