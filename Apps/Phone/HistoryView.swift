import SwiftUI
import BatwalkCore

/// History (board: iPhone › 3. History): 2×2 stat cards and a Hatch Timeline,
/// newest first. Game events only — never raw Health data.
struct HistoryView: View {
    @Environment(GameStore.self) private var store

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 2)

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BatwalkSpacing.lg) {
                    PhoneHeader(title: "History")

                    LazyVGrid(columns: columns, spacing: 12) {
                        StatCard(title: "Bats Found", value: "\(state.collection.count) / \(Roster.all.count)") {
                            BatSilhouette(size: 22, color: BatwalkColor.accent)
                        }
                        StatCard(title: "Shiny Bats", value: "\(state.collection.values.filter(\.hasShiny).count)") {
                            Image(systemName: "sparkles").foregroundStyle(BatwalkColor.accent)
                        }
                        StatCard(title: "Eggs Hatched", value: "\(state.history.count)") {
                            EggIcon(size: 20)
                        }
                        StatCard(title: "Steps Walked", value: state.lifetimeCreditedSteps.formatted()) {
                            Image(systemName: "figure.walk").foregroundStyle(BatwalkColor.accent)
                        }
                    }

                    Text("Hatch Timeline")
                        .font(BatwalkFont.rounded(.title3, weight: .bold))
                        .foregroundStyle(BatwalkColor.textPrimaryLight)
                        .accessibilityAddTraits(.isHeader)

                    if state.history.isEmpty {
                        PhoneEmptyState()
                    } else {
                        VStack(spacing: 0) {
                            let records = Array(state.history.reversed())
                            ForEach(Array(records.enumerated()), id: \.offset) { index, record in
                                TimelineEntry(isLast: index == records.count - 1 && placeholders == 0) {
                                    HatchHistoryRow(record: record)
                                }
                            }
                            ForEach(0..<placeholders, id: \.self) { i in
                                TimelineEntry(isLast: i == placeholders - 1, muted: true) { UndiscoveredRow() }
                            }
                        }
                    }
                }
                .padding(BatwalkSpacing.lg)
            }
            .background(BatwalkColor.lightBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var state: GameState { store.state }
    private var placeholders: Int { state.collection.count < Roster.all.count ? 2 : 0 }
}

/// Timeline rail: dot + connecting line on the leading edge.
private struct TimelineEntry<Content: View>: View {
    var isLast = false
    var muted = false
    @ViewBuilder var content: () -> Content

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            VStack(spacing: 0) {
                Circle()
                    .fill(muted ? BatwalkColor.sage.opacity(0.5) : BatwalkColor.accent)
                    .frame(width: 10, height: 10)
                    .overlay(Circle().strokeBorder(.white, lineWidth: 2))
                    .padding(.top, 28)
                if !isLast {
                    Rectangle()
                        .fill(BatwalkColor.sage.opacity(0.6))
                        .frame(width: 2)
                }
            }
            .frame(width: 12)
            content()
                .padding(.bottom, 10)
        }
    }
}
