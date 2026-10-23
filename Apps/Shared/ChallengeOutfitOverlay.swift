import SwiftUI
import BatwalkCore

/// A small pixel accessory on the existing portrait. No replacement bat art.
struct ChallengeOutfitOverlay: View {
    let outfit: ChallengeOutfit?
    var body: some View {
        GeometryReader { geometry in
            if let outfit {
                let color: Color = outfit.cosmetic.color == "pumpkin" ? .orange : outfit.cosmetic.color == "frost" ? .cyan : outfit.cosmetic.color == "lilac" ? .purple : BatwalkColor.sage
                Canvas { context, size in
                    let u = size.width / 64
                    func block(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ c: Color) {
                        context.fill(Path(CGRect(x: x * u, y: y * u, width: w * u, height: h * u)),
                                     with: .color(c), style: FillStyle(antialiased: false))
                    }
                    block(23, 42, 18, 4, color.opacity(0.85))
                    if outfit.cosmetic.color == "pumpkin" {
                        block(22, 46, 7, 4, color.opacity(0.8)); block(20, 50, 8, 4, color.opacity(0.8))
                        block(40, 46, 3, 4, color.opacity(0.8))
                    }
                    block(35, 46, 5, 7, color)
                    block(36, 52, 5, 2, color.opacity(0.8))
                    block(24, 42, 16, 1, Color.white.opacity(0.5))
                    if outfit.tier >= .silver {
                        context.draw(Text(String(outfit.monthKey.suffix(2)))
                            .font(.system(size: u * 3, weight: .bold, design: .monospaced)).foregroundColor(.white),
                            at: CGPoint(x: u * 32, y: u * 44))
                    }
                    if outfit.tier == .gold {
                        for (x, y) in [(18.0, 38.0), (45.0, 39.0), (43.0, 52.0)] {
                            block(x, y, 1, 3, .yellow); block(x - 1, y + 1, 3, 1, .yellow)
                        }
                    }
                }
                .frame(width: geometry.size.width, height: geometry.size.width)
                .shadow(color: outfit.tier == .gold ? Color.yellow.opacity(0.5) : .clear, radius: 5)
                .accessibilityHidden(true)
            }
        }
        .allowsHitTesting(false)
    }
}
