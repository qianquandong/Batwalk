// swift-tools-version:5.9
// BatwalkCore — pure-Swift game rules for Batwalk.
// No UIKit/SwiftUI/HealthKit/SwiftData imports here, so the whole rule set
// is unit-testable on any machine (`swift test`) and shared by Watch, iPhone
// and the complication.
import PackageDescription

let package = Package(
    name: "BatwalkCore",
    platforms: [
        .watchOS(.v10),
        .iOS(.v17),
        .macOS(.v14),
    ],
    products: [
        .library(name: "BatwalkCore", targets: ["BatwalkCore"]),
    ],
    targets: [
        .target(name: "BatwalkCore"),
        .testTarget(name: "BatwalkCoreTests", dependencies: ["BatwalkCore"]),
    ]
)
