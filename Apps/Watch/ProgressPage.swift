import SwiftUI
import BatwalkCore

/// Progress (board: Watch › 2. Progress): glowing ring, steps to hatch, two stat rows.
/// Health troubleshooting lives in Settings, not here.
struct ProgressPage: View {
    @Environment(GameStore.self) private var store
    @Binding var page: Int
    let steps: StepService

    @State private var showEggPicker = false
    @State private var health: HealthStatus = .noData

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 6) {
                    if let egg = store.state.egg {
                        BatwalkProgressRing(progress: egg.progress, lineWidth: 8) {
                            VStack(spacing: 2) {
                                Text("\(Int((egg.progress * 100).rounded(.down)))%")
                                    .font(BatwalkFont.rounded(.title3, weight: .bold))
                                    .monospacedDigit()
                                    .foregroundStyle(.white)
                                EggIcon(type: egg.type, size: 14)
                            }
                        }
                        .frame(width: 78, height: 78)
                        .padding(.top, 2)

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
                    Button {
                        Task { await store.syncSteps(using: steps) }
                    } label: {
                        Label(updateLabel, systemImage: "arrow.clockwise")
                            .font(BatwalkFont.micro)
                    }
                    .disabled(StepSyncCoordinator.shared.isSyncing)
                    NavigationLink("Step Count help") { HealthAccessView(steps: steps, status: $health) }
                        .font(BatwalkFont.micro)
                }
                .padding(.horizontal, BatwalkSpacing.xs)
                .batwalkAppear()
            }
            .navigationTitle("Progress")
            .watchPageBackground()
        }
        .sheet(isPresented: $showEggPicker) { EggPickerView() }
        .task { health = await HealthAccessView.currentStatus(steps: steps, state: store.state) }
    }

    private var todaySteps: Int {
        let ledger = store.state.ledger
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = ledger.timeZoneIdentifier.flatMap(TimeZone.init(identifier:)) ?? .current
        return ledger.dayKey == DayKey.make(.now, calendar: calendar) ? ledger.lastDailyTotal : 0
    }

    private var updateLabel: String {
        if store.isDemo { return "Update steps" }
        switch StepSyncCoordinator.shared.status {
        case .idle: return "Update steps"
        case .updating: return "Updating…"
        case .failed: return "Couldn't update · Try again"
        case .updated(_, let date): return "Updated \(date.formatted(date: .omitted, time: .shortened)) · Refresh"
        }
    }
}
