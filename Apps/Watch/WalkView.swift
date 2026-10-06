import SwiftUI
import BatwalkCore

/// Today's steps and egg progress — game progress first, fitness data second (PRD §2.4).
struct WalkView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        let state = store.state
        ScrollView {
            VStack(spacing: 8) {
                if let egg = state.egg {
                    Gauge(value: egg.progress) {
                        Text(egg.type.displayName)
                    } currentValueLabel: {
                        Text("\(Int(egg.progress * 100))%")
                    }
                    .gaugeStyle(.accessoryCircularCapacity)
                    .tint(.purple)

                    Text(egg.isReady ? "Ready to hatch!" : "\(egg.stepsRemaining.formatted()) steps to hatch")
                        .font(.headline)
                        .multilineTextAlignment(.center)
                } else {
                    Text("No egg yet — pick one on the home screen.")
                        .font(.footnote)
                        .multilineTextAlignment(.center)
                }

                Divider()

                LabeledContent("Today", value: todaySteps.formatted())
                LabeledContent("Fruit", value: "\(state.fruit) 🍓")
                if state.bankedSteps > 0 {
                    LabeledContent("Saved for next egg", value: state.bankedSteps.formatted())
                }
                if todaySteps == 0 {
                    // Graceful non-progress state (PRD §5.4). HealthKit hides read denials,
                    // so this hint is shown whenever nothing has been counted yet today.
                    Text("No steps yet today. If you're walking and this stays at 0, allow Step Count in Settings › Health › Batwalk.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal, 4)
        }
        .navigationTitle("Walk")
    }

    private var todaySteps: Int {
        let ledger = store.state.ledger
        return ledger.dayKey == DayKey.make(.now) ? ledger.lastDailyTotal : 0
    }
}
