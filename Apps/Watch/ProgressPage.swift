import SwiftUI
import BatwalkCore

/// An inset egg, a short progress line, and one quiet control row.
struct ProgressPage: View {
    @Environment(GameStore.self) private var store
    @Environment(\.dynamicTypeSize) private var typeSize
    @Environment(\.batPageVisible) private var pageVisible
    @Binding var page: Int
    let steps: StepService
    @State private var showEggPicker = false
    @State private var settings = DemoMode.scenario == "settings" || DemoMode.scenario == "health-error"
    @State private var showStepAccess = false
    @State private var health: HealthStatus = .noData

    var body: some View {
        TimelineView(.everyMinute) { context in
            Group {
                if typeSize.isAccessibilitySize {
                    ScrollView { eggContent(size: 72).padding(14) }
                } else {
                    GeometryReader { geo in
                        eggContent(size: min(88, max(36, geo.size.height - 112)))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                    }
                }
            }
            .foregroundStyle(BatwalkColor.cloud)
            .watchPageBackground(DemoMode.timeOfDay(at: context.date))
        }
        .sheet(isPresented: $showEggPicker) { EggPickerView() }
        .sheet(isPresented: $settings) { SettingsView(steps: steps) }
        .sheet(isPresented: $showStepAccess) {
            NavigationStack { HealthAccessView(steps: steps, status: $health) }
        }
        .environment(\.batPageVisible, pageVisible && !settings && !showEggPicker && !showStepAccess)
    }

    private func eggContent(size: CGFloat) -> some View {
        VStack(spacing: 6) {
            EggSprite(type: store.state.egg?.type ?? .tiny,
                      state: store.state.egg?.visualState ?? .calm, size: size)
                .accessibilityHidden(true)
            if let egg = store.state.egg {
                VStack(spacing: 6) {
                    ProgressView(value: egg.progress)
                        .tint(BatwalkColor.ringMint)
                        .frame(maxWidth: 100)
                        .accessibilityHidden(true)
                    if egg.isReady {
                        Text("Ready!").font(BatwalkFont.caption)
                    } else {
                        (Text(egg.creditedSteps.formatted()).fontWeight(.semibold)
                         + Text(" / \(egg.targetSteps.formatted())")
                            .foregroundColor(BatwalkColor.textSecondaryDark))
                            .font(BatwalkFont.micro).monospacedDigit()
                            .lineLimit(1).minimumScaleFactor(0.7)
                    }
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Egg progress")
                .accessibilityValue("\(egg.creditedSteps) of \(egg.targetSteps) steps, \(egg.stepsRemaining) remaining")
            }
            HStack(spacing: 6) {
                Button { settings = true } label: { Image(systemName: "ellipsis") }
                    .buttonStyle(WatchPetControlStyle())
                    .accessibilityLabel("More options")
                if store.state.egg == nil {
                    Button("Next egg") { showEggPicker = true }
                        .buttonStyle(BatwalkPrimaryButtonStyle())
                } else if store.state.isEggReady {
                    Button("Hatch") { page = 0 }
                        .buttonStyle(BatwalkPrimaryButtonStyle())
                } else if needsStepHelp {
                    Button("Check Steps") { showStepAccess = true }
                        .buttonStyle(BatwalkPrimaryButtonStyle())
                }
            }
            .frame(minHeight: 44)
        }
    }

    private var needsStepHelp: Bool {
        guard !store.isDemo else { return false }
        switch StepSyncCoordinator.shared.status {
        case .failed: return true
        case .updated(let total, _): return total == 0
        case .idle, .updating: return false
        }
    }
}
