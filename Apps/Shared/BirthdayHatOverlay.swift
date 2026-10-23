import SwiftUI
import BatwalkCore

/// A small accessory above the existing portrait; every year gets its own colour.
/// The anchors follow the original characters' different heads, never alter their art.
struct BirthdayHatOverlay: View {
    let speciesID: String
    let year: Int?
    var mood: BatMood = .awake

    private var crown: CGPoint {
        // Mochi's accepted pilot frames have different resting head heights.
        if speciesID == "mochi" {
            let y: CGFloat
            switch mood {
            case .happy: y = 19
            case .eating: y = 15
            case .sleeping, .drowsy: y = 21
            default: y = 25
            }
            return .init(x: 32, y: y)
        }
        let anchors: [String: CGPoint] = [
            "cocoa": .init(x: 37, y: 11), "long-ear": .init(x: 35, y: 44),
            "fruit": .init(x: 36, y: 13), "cave": .init(x: 35, y: 30),
            "sleepy": .init(x: 41, y: 24), "dust": .init(x: 35, y: 12),
            "pebble": .init(x: 31, y: 15), "strawberry": .init(x: 31, y: 27),
            "blossom": .init(x: 37, y: 24), "moss": .init(x: 34, y: 23),
            "sunset": .init(x: 40, y: 27), "snow": .init(x: 37, y: 11),
            "cloud": .init(x: 32, y: 24), "moonwing": .init(x: 33, y: 22),
            "golden": .init(x: 34, y: 22), "crystal": .init(x: 32, y: 25),
            "vampire": .init(x: 32, y: 15), "galaxy": .init(x: 31, y: 22),
            "eclipse": .init(x: 32, y: 24)
        ]
        return anchors[speciesID] ?? .init(x: 32, y: 20)
    }

    var body: some View {
        Canvas { context, size in
            if let year {
                let u = size.width / 64
                let colors = [Color(red: 0.83, green: 0.62, blue: 0.68),
                              Color(red: 0.66, green: 0.75, blue: 0.58),
                              Color(red: 0.72, green: 0.66, blue: 0.86),
                              Color(red: 0.60, green: 0.76, blue: 0.82)]
                let color = colors[((year % colors.count) + colors.count) % colors.count]
                func block(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: Color) {
                    context.fill(Path(CGRect(x: (crown.x + x) * u, y: (crown.y + y) * u,
                                            width: w * u, height: h * u)),
                                 with: .color(color), style: FillStyle(antialiased: false))
                }
                let edge = Color(red: 0.30, green: 0.25, blue: 0.30)
                block(-1, -8, 2, 2, Color(red: 0.98, green: 0.83, blue: 0.54))
                block(-1, -6, 2, 2, edge)
                block(-2, -4, 4, 2, edge)
                block(-3, -2, 6, 2, edge)
                block(-1, -5, 2, 2, color)
                block(-2, -3, 4, 2, color)
                block(-3, -1, 6, 1, color)
                block(0, -4, 1, 1, .white.opacity(0.85))
                block(-1, -2, 1, 1, .white.opacity(0.85))
                block(-4, 0, 8, 1, Color(red: 0.98, green: 0.83, blue: 0.54))
            }
        }
        .allowsHitTesting(false).accessibilityHidden(true)
    }
}
