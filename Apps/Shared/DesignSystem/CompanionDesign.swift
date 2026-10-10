import SwiftUI
import BatwalkCore

extension OwnedBat {
    var companionTitle: String {
        nickname ?? (species?.name.replacingOccurrences(of: " Bat", with: "") ?? displayName)
    }
}

/// Same egg, wording and progress on both screens. The phone has no hatch action.
struct HatchProgressSummary: View {
    let egg: ActiveEgg
    var dark = true
    var compact = false

    var body: some View {
        HStack(spacing: compact ? 8 : 14) {
            EggIcon(type: egg.type, size: compact ? 23 : 34)
                .accessibilityHidden(true)
            VStack(alignment: .leading, spacing: 6) {
                if !compact {
                    Text(egg.isReady ? "Ready to meet you" : "Next little friend")
                        .font(BatwalkFont.headline)
                }
                Text(egg.isReady ? "Ready to hatch!" : "\(egg.stepsRemaining.formatted()) steps to hatch")
                    .font(compact ? BatwalkFont.micro : BatwalkFont.caption)
                    .monospacedDigit()
                    .fixedSize(horizontal: false, vertical: true)
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(dark ? BatwalkColor.cloud.opacity(0.14) : BatwalkColor.lockedBatLight)
                        Capsule().fill(BatwalkColor.accentSoft)
                            .frame(width: geometry.size.width * max(0, min(1, egg.progress)))
                    }
                }
                    .frame(height: compact ? 4 : 5)
                    .accessibilityLabel("Egg progress")
                    .accessibilityValue("\(Int(egg.progress * 100)) percent")
            }
        }
        .foregroundStyle(dark ? BatwalkColor.cloud : BatwalkColor.textPrimaryLight)
        .accessibilityElement(children: .combine)
    }
}

