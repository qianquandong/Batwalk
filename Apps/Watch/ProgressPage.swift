import SwiftUI
import BatwalkCore

/// One egg and one number. Statistics and explanations live on iPhone.
struct ProgressPage: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.batPageVisible) private var pageVisible
    @Binding var page: Int
    let steps: StepService
    @State private var showEggPicker = false
    @State private var settings = DemoMode.scenario == "settings" || DemoMode.scenario == "health-error"

    var body: some View {
        TimelineView(.everyMinute) { context in
            Group {
                if typeSize.isAccessibilitySize {
                    ScrollView {
                        VStack(spacing: 12) {
                            eggTitle
                            eggPicture(size: 104)
                            eggFooter
                        }
                        .padding(.horizontal, 8)
                    }
                } else {
                    GeometryReader { geo in
                        let size = min(100, max(64, geo.size.height - 74))
                        VStack(spacing: 4) {
                            eggTitle.frame(height: 18)
                            eggPicture(size: size)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                            eggFooter
                        }
                        .frame(width: geo.size.width, height: geo.size.height)
                    }
                }
            }
            .foregroundStyle(BatwalkColor.cloud)
            .watchPageBackground(DemoMode.timeOfDay(at: context.date))
        }
        .sheet(isPresented: $showEggPicker) { EggPickerView() }
        .sheet(isPresented: $settings) { SettingsView(steps: steps) }
        .environment(\.batPageVisible, pageVisible && !settings && !showEggPicker)
    }

    private var eggTitle: some View {
        Text("Egg")
            .font(BatwalkFont.rounded(.caption2, weight: .medium))
            .foregroundStyle(BatwalkColor.textSecondaryDark)
            .lineLimit(1).minimumScaleFactor(0.7)
    }

    private func eggPicture(size: CGFloat) -> some View {
        BatwalkProgressRing(progress: store.state.egg?.progress ?? 0, lineWidth: 3, pulses: false) {
            EggSprite(type: store.state.egg?.type ?? .tiny,
                      state: store.state.egg?.visualState ?? .calm, size: size * 0.78)
        }
        .frame(width: size, height: size)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Egg progress")
        .accessibilityValue(store.state.egg.map { "\(Int($0.progress * 100)) percent" } ?? "No egg")
    }

    private var eggFooter: some View {
        HStack(spacing: 8) {
            // Stay out of the watchOS navigation toolbar; it triggered a layout
            // assertion on the simulator. The scene control retains a 44 pt target.
            Button { settings = true } label: {
                Image(systemName: "ellipsis").font(.system(size: 18, weight: .semibold))
            }
            .buttonStyle(WatchPetControlStyle())
            .accessibilityLabel("More options")

            Group {
                if let egg = store.state.egg {
                    if egg.isReady {
                        Button("Hatch") { page = 0 }
                            .buttonStyle(BatwalkPrimaryButtonStyle())
                    } else {
                        HStack(spacing: 6) {
                            Image(systemName: "figure.walk")
                                .font(BatwalkFont.caption)
                                .foregroundStyle(BatwalkColor.textSecondaryDark)
                            Text(egg.stepsRemaining.formatted())
                                .font(BatwalkFont.headline).monospacedDigit()
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(egg.stepsRemaining) steps to hatch")
                    }
                } else {
                    Button("Next egg") { showEggPicker = true }
                        .buttonStyle(BatwalkPrimaryButtonStyle())
                }
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .padding(.horizontal, 8)
    }
}
