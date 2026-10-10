import SwiftUI
import BatwalkCore

/// Collection Stats (board: iPhone › 5. Collection Progress): progress hero,
/// milestones 5 / 10 / 20 / all, recent hatches.
struct StatsView: View {
    @Environment(GameStore.self) private var store
    @Binding var tab: PhoneTab

    private let milestones = [5, 10, 20, Roster.all.count]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: BatwalkSpacing.lg) {
                    PhoneHeader(title: "My Collection")

                    VStack(spacing: 4) {
                        BatwalkProgressRing(progress: fraction, lineWidth: 14, pulses: false,
                                            track: BatwalkColor.accent.opacity(0.14)) {
                            VStack(spacing: 2) {
                                BatSilhouette(size: 30, color: BatwalkColor.accent)
                                Text("\(found) / \(Roster.all.count)")
                                    .font(BatwalkFont.rounded(.title, weight: .bold))
                                    .foregroundStyle(BatwalkColor.textPrimaryLight)
                                    .monospacedDigit()
                                Text("Bats Discovered")
                                    .font(BatwalkFont.rounded(.caption2, weight: .medium))
                                    .foregroundStyle(BatwalkColor.textSecondaryLight)
                                Text("\(Int((fraction * 100).rounded()))%")
                                    .font(BatwalkFont.rounded(.subheadline, weight: .bold))
                                    .foregroundStyle(BatwalkColor.accent)
                            }
                        }
                        .frame(width: 180, height: 180)
                        .padding(.vertical, BatwalkSpacing.sm)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(BatwalkSpacing.lg)
                    .background(
                        RoundedRectangle(cornerRadius: 26, style: .continuous)
                            .fill(BatwalkGradient.lightArt)
                    )

                    HStack {
                        ForEach(milestones, id: \.self) { goal in
                            MilestoneBadge(goal: goal, done: found >= goal)
                                .frame(maxWidth: .infinity)
                        }
                    }
                    .batwalkLightCard(padding: 14, radius: 22)

                    HStack {
                        Text("Recent Hatches")
                            .font(BatwalkFont.rounded(.title3, weight: .bold))
                            .foregroundStyle(BatwalkColor.textPrimaryLight)
                        Spacer()
                        Button {
                            tab = .journal
                        } label: {
                            HStack(spacing: 2) { Text("See All"); Image(systemName: "chevron.right") }
                                .font(BatwalkFont.rounded(.subheadline, weight: .semibold))
                        }
                    }

                    if store.state.history.isEmpty {
                        PhoneEmptyState()
                    } else {
                        VStack(spacing: 10) {
                            ForEach(Array(store.state.history.suffix(3).reversed().enumerated()), id: \.offset) { _, record in
                                HatchHistoryRow(record: record)
                            }
                            if found < Roster.all.count { UndiscoveredRow() }
                        }
                    }
                }
                .padding(BatwalkSpacing.lg)
            }
            .background(BatwalkColor.lightBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
    }

    private var found: Int { store.state.collection.count }
    private var fraction: Double { Double(found) / Double(Roster.all.count) }
}

/// Milestone: brand gradient when reached, muted with a lock when not.
private struct MilestoneBadge: View {
    let goal: Int
    let done: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle()
                    .fill(done ? AnyShapeStyle(BatwalkGradient.primary) : AnyShapeStyle(BatwalkColor.lockedBatLight))
                    .frame(width: 52, height: 52)
                    .shadow(color: done ? BatwalkColor.accent.opacity(0.35) : .clear, radius: 6, y: 2)
                if done {
                    BatSilhouette(size: 28, color: .white)
                } else {
                    Image(systemName: "lock.fill")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(BatwalkColor.textSecondaryLight.opacity(0.6))
                }
            }
            Text("\(goal)")
                .font(BatwalkFont.rounded(.subheadline, weight: .bold))
                .foregroundStyle(done ? BatwalkColor.textPrimaryLight : BatwalkColor.textSecondaryLight)
            Text("Bats")
                .font(BatwalkFont.rounded(.caption2, weight: .medium))
                .foregroundStyle(BatwalkColor.textSecondaryLight)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(goal) bats milestone, \(done ? "reached" : "locked")")
    }
}
