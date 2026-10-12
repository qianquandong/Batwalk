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
        NavigationStack {
            Group {
                if typeSize.isAccessibilitySize {
                    ScrollView { eggScene.frame(minHeight: 300) }
                } else { eggScene }
            }
            .watchPageBackground()
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button { settings = true } label: { Image(systemName: "ellipsis") }
                        .accessibilityLabel("More options")
                }
            }
        }
        .sheet(isPresented: $showEggPicker) { EggPickerView() }
        .sheet(isPresented: $settings) { SettingsView(steps: steps) }
        .environment(\.batPageVisible, pageVisible && !settings && !showEggPicker)
    }

    private var eggScene: some View {
        GeometryReader { geometry in
            let size = max(64, min(110, geometry.size.height - 92))
            VStack(spacing: 6) {
                Spacer(minLength: 0)
                if let egg = store.state.egg {
                    BatwalkProgressRing(progress: egg.progress, lineWidth: 5, pulses: false) {
                        EggSprite(type: egg.type, state: egg.visualState, size: size * 0.72)
                    }
                    .frame(width: size, height: size)
                    .accessibilityLabel("Egg progress")
                    if egg.isReady {
                        Button("Hatch") { page = 0 }
                            .buttonStyle(BatwalkPrimaryButtonStyle())
                    } else {
                        Text(egg.stepsRemaining.formatted())
                            .font(BatwalkFont.rounded(.title2, weight: .semibold)).monospacedDigit()
                        Text("steps to hatch")
                            .font(BatwalkFont.micro).foregroundStyle(BatwalkColor.textSecondaryDark)
                    }
                } else {
                    EggIcon(size: size * 0.72).accessibilityHidden(true)
                    Button("Next egg") { showEggPicker = true }
                        .buttonStyle(BatwalkPrimaryButtonStyle())
                }
                Spacer(minLength: 0)
            }
            .foregroundStyle(BatwalkColor.cloud)
            .padding(.horizontal, BatwalkSpacing.sm)
            .frame(width: geometry.size.width, height: geometry.size.height)
        }
    }
}
