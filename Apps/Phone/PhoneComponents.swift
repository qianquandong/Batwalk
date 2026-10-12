import SwiftUI
import BatwalkCore

// iPhone-only reusable components (UI_REDESIGN_TASKS P5).

/// Large rounded page header used instead of the default navigation title.
struct PhoneHeader: View {
    let title: String
    var trailing: String? = nil

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(BatwalkFont.rounded(.largeTitle, weight: .bold))
                .foregroundStyle(BatwalkColor.textPrimaryLight)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(BatwalkFont.rounded(.subheadline, weight: .semibold))
                    .foregroundStyle(BatwalkColor.textSecondaryLight)
            }
        }
        .accessibilityAddTraits(.isHeader)
    }
}

/// Two-option pill control (Normal | Shiny) in brand purple.
struct SegmentedPill<Value: Hashable>: View {
    let options: [(Value, String)]
    @Binding var selection: Value
    @Namespace private var ns

    var body: some View {
        HStack(spacing: 4) {
            ForEach(options.indices, id: \.self) { index in
                let value = options[index].0
                let label = options[index].1
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) { selection = value }
                } label: {
                    Text(label)
                        .font(BatwalkFont.rounded(.subheadline, weight: .semibold))
                        .foregroundStyle(selection == value ? BatwalkColor.buttonText : BatwalkColor.textSecondaryLight)
                        .frame(maxWidth: .infinity, minHeight: 34)
                        .background {
                            if selection == value {
                                Capsule().fill(BatwalkGradient.button)
                                    .matchedGeometryEffect(id: "pill", in: ns)
                            }
                        }
                }
                .buttonStyle(.plain)
                .accessibilityAddTraits(selection == value ? .isSelected : [])
            }
        }
        .padding(4)
        .background(Capsule().fill(BatwalkColor.lightTint))
    }
}

/// Existing portraits retain their individual proportions; no alternate character art.
/// Rarity always shows, in its own colour; the companion gets a small Watch badge.
struct BatCard: View {
    let species: Species
    let shiny: Bool
    var isCompanion = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            GeometryReader { geometry in
                BatSprite(speciesID: species.id, shiny: shiny, size: min(160, geometry.size.width))
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
            .frame(height: 148)
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(String(format: "%02d", species.number))
                    .foregroundStyle(BatwalkColor.textSecondaryLight)
                Text(species.name.replacingOccurrences(of: " Bat", with: ""))
                    .fontWeight(.semibold)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(BatwalkFont.caption)
            HStack(spacing: 6) {
                RarityChip(rarity: species.rarity, dark: false)
                if shiny { VariantChip(shiny: true, dark: false) }
            }
        }
        .foregroundStyle(BatwalkColor.textPrimaryLight)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BatwalkColor.lightTint.opacity(0.45), in: RoundedRectangle(cornerRadius: 20))
        .overlay(alignment: .topTrailing) {
            if isCompanion {
                Label("On Watch", systemImage: "applewatch")
                    .font(BatwalkFont.rounded(.caption2, weight: .semibold))
                    .foregroundStyle(BatwalkColor.buttonText)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(BatwalkColor.accentSoft, in: Capsule())
                    .padding(10)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(species.name), \(species.rarity.displayName)\(shiny ? ", Shiny" : "")\(isCompanion ? ", on your Watch" : "")")
    }
}

struct LockedBatCard: View {
    let number: Int
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ZStack {
                BatSilhouette(size: 80, color: BatwalkColor.textSecondaryLight.opacity(0.25))
                Text("?").font(BatwalkFont.title).foregroundStyle(BatwalkColor.lightCard)
            }
            .frame(maxWidth: .infinity).frame(height: 148)
            Text(String(format: "%02d", number)).font(BatwalkFont.caption)
            Text("Undiscovered").font(BatwalkFont.micro).padding(.vertical, 4)
        }
        .foregroundStyle(BatwalkColor.textSecondaryLight)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(BatwalkColor.lightTint.opacity(0.3), in: RoundedRectangle(cornerRadius: 20))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Bat number \(number), not discovered yet")
    }
}

/// Compact stat tile (History, 2×2).
struct StatCard<Icon: View>: View {
    let title: String
    let value: String
    @ViewBuilder var icon: () -> Icon

    var body: some View {
        HStack(spacing: 10) {
            icon()
                .frame(width: 36, height: 36)
                .background(Circle().fill(BatwalkColor.lightTint))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(BatwalkFont.rounded(.caption, weight: .medium))
                    .foregroundStyle(BatwalkColor.textSecondaryLight)
                Text(value)
                    .font(BatwalkFont.rounded(.title3, weight: .bold))
                    .foregroundStyle(BatwalkColor.textPrimaryLight)
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
            Spacer(minLength: 0)
        }
        .batwalkLightCard(padding: 12, radius: 18)
        .accessibilityElement(children: .combine)
    }
}

/// Labelled information row (Bat Detail).
struct BatInfoRow<Icon: View, Detail: View>: View {
    let title: String
    var value: String? = nil
    @ViewBuilder var icon: () -> Icon
    @ViewBuilder var detail: () -> Detail

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            icon()
                .frame(width: 34, height: 34)
                .background(Circle().fill(BatwalkColor.lightTint))
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(title)
                        .font(BatwalkFont.rounded(.subheadline, weight: .semibold))
                        .foregroundStyle(BatwalkColor.textPrimaryLight)
                    Spacer()
                    if let value {
                        Text(value)
                            .font(BatwalkFont.rounded(.subheadline, weight: .semibold))
                            .foregroundStyle(BatwalkColor.textSecondaryLight)
                    }
                }
                detail()
            }
        }
        .padding(.vertical, 10)
        .accessibilityElement(children: .combine)
    }
}

extension BatInfoRow where Detail == EmptyView {
    init(title: String, value: String? = nil, @ViewBuilder icon: @escaping () -> Icon) {
        self.init(title: title, value: value, icon: icon, detail: { EmptyView() })
    }
}

/// Hatch history row: thumbnail, name, variant + egg chips, date / time.
struct HatchHistoryRow: View {
    let record: HatchRecord

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous).fill(BatwalkGradient.lightArt)
                BatSprite(speciesID: record.speciesID, shiny: record.isShiny, mood: .awake, size: 40)
            }
            .frame(width: 50, height: 50)
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 4) {
                    Text(Roster.species(record.speciesID)?.name ?? record.speciesID)
                        .font(BatwalkFont.rounded(.subheadline, weight: .semibold))
                        .foregroundStyle(BatwalkColor.textPrimaryLight)
                        .lineLimit(1)
                    if record.outcome != .duplicate {
                        Text("New!")
                            .font(BatwalkFont.rounded(.caption2, weight: .bold))
                            .foregroundStyle(BatwalkColor.rose)
                    }
                }
                HStack(spacing: 4) {
                    VariantChip(shiny: record.isShiny, dark: false)
                    if record.source == .moonDust {
                        ChipView(text: "Moon Dust", symbol: "sparkle", color: BatwalkColor.rarityShiny, dark: false)
                    } else {
                        ChipView(text: record.eggType.displayName, color: BatwalkColor.accent, dark: false)
                    }
                }
            }
            Spacer(minLength: 4)
            VStack(alignment: .trailing, spacing: 2) {
                Text(record.hatchedAt.formatted(date: .abbreviated, time: .omitted))
                Text(record.hatchedAt.formatted(date: .omitted, time: .shortened))
            }
            .font(BatwalkFont.rounded(.caption2, weight: .medium))
            .foregroundStyle(BatwalkColor.textSecondaryLight)
        }
        .batwalkLightCard(padding: 10, radius: 18)
        .accessibilityElement(children: .combine)
    }
}

/// Light-theme empty state wrapper.
struct PhoneEmptyState: View {
    var body: some View {
        BatwalkEmptyState(title: "No bats here yet!",
                          message: "Open Batwalk on your Apple Watch and walk to hatch your first bat.")
    }
}
