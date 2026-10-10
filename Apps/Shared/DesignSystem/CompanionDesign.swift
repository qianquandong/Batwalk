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
                ProgressView(value: egg.progress)
                    .tint(BatwalkColor.accentSoft)
                    .accessibilityLabel("Egg progress")
            }
        }
        .foregroundStyle(dark ? BatwalkColor.cloud : BatwalkColor.textPrimaryLight)
        .accessibilityElement(children: .combine)
    }
}

