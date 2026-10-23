import SwiftUI

/// A small accessory above the existing portrait; every year gets its own colour.
/// The anchors follow the original characters' different heads, never alter their art.
struct BirthdayHatOverlay: View {
    let speciesID: String
    let year: Int?

    private var crown: CGPoint {
        let anchors: [String: CGPoint] = [
            "mochi": .init(x: 31, y: 16), "cocoa": .init(x: 32, y: 13),
            "long-ear": .init(x: 31, y: 37), "fruit": .init(x: 32, y: 18),
            "cave": .init(x: 32, y: 24), "sleepy": .init(x: 35, y: 21),
            "dust": .init(x: 33, y: 20), "pebble": .init(x: 32, y: 17),
            "strawberry": .init(x: 32, y: 23), "blossom": .init(x: 32, y: 27),
            "moss": .init(x: 32, y: 23), "sunset": .init(x: 40, y: 22),
            "snow": .init(x: 32, y: 17), "cloud": .init(x: 32, y: 30),
            "moonwing": .init(x: 37, y: 25), "golden": .init(x: 32, y: 28),
            "crystal": .init(x: 32, y: 34), "vampire": .init(x: 32, y: 20),
            "galaxy": .init(x: 32, y: 28), "eclipse": .init(x: 32, y: 29)
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
