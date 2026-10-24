import SwiftUI
import BatwalkCore

/// The next discovery at a glance. Remaining steps lead; maintenance stays quiet.
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
            GeometryReader { geometry in
                VStack(spacing: BatwalkSpacing.xs) {
                    if typeSize.isAccessibilitySize {
                        ScrollView {
                            eggContent(size: 48)
                                .padding(.vertical, BatwalkSpacing.sm)
                        }
                    } else {
                        ViewThatFits(in: .vertical) {
                            eggContent(size: min(76, max(28, geometry.size.height - 128)))
                            ScrollView { eggContent(size: 36) }
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                    actions
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, BatwalkSpacing.sm)
                .padding(.bottom, BatwalkSpacing.xs)
                .frame(width: geometry.size.width, height: geometry.size.height)
            }
            .foregroundStyle(BatwalkColor.cloud)
            .watchPageBackground(DemoMode.timeOfDay(at: context.date), scenery: false)
        }
        .sheet(isPresented: $showEggPicker) { EggPickerView() }
        .sheet(isPresented: $settings) {
            SettingsView(steps: steps, onReplay: {
                settings = false
                page = 0
            })
        }
        .sheet(isPresented: $showStepAccess) {
            NavigationStack { HealthAccessView(steps: steps, status: $health) }
        }
        .environment(\.batPageVisible, pageVisible && !settings && !showEggPicker && !showStepAccess)
    }

    private func eggContent(size: CGFloat) -> some View {
        VStack(spacing: BatwalkSpacing.sm) {
            EggSprite(type: store.state.egg?.type ?? .tiny,
                      state: store.state.egg?.visualState ?? .calm, size: size,
                      animated: false)
                .opacity(store.state.egg == nil ? 0.45 : 1)
                .accessibilityHidden(true)
            if let egg = store.state.egg {
                VStack(spacing: 6) {
                    GeometryReader { geometry in
                        ZStack(alignment: .leading) {
                            Capsule().fill(BatwalkColor.cloud.opacity(0.18))
                            Capsule().fill(BatwalkColor.ringMint)
                                .frame(width: geometry.size.width * egg.progress)
                        }
                    }
                    .frame(width: 100, height: 3)
                    .accessibilityHidden(true)
                    Text(egg.isReady ? "Ready to hatch" : "\(egg.stepsRemaining.formatted()) steps to hatch")
                        .font(BatwalkFont.caption)
                        .monospacedDigit()
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                    Text("\(egg.creditedSteps.formatted()) / \(egg.targetSteps.formatted())")
                        .font(BatwalkFont.micro)
                        .monospacedDigit()
                        .foregroundStyle(BatwalkColor.textSecondaryDark)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(egg.isReady ? "Ready to hatch" : "Egg progress")
                .accessibilityValue("\(egg.stepsRemaining) steps to hatch. \(egg.creditedSteps) of \(egg.targetSteps) steps.")
                if let message = stepMessage, !egg.isReady {
                    Text(message)
                        .font(BatwalkFont.micro)
                        .foregroundStyle(BatwalkColor.textSecondaryDark)
                        .multilineTextAlignment(.center)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                Text("A new little journey")
                    .font(BatwalkFont.caption)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder private var actions: some View {
        // Large type keeps the primary action wide. Content above can scroll,
        // but neither the next step nor More disappears below it.
        if typeSize.isAccessibilitySize, hasPrimaryAction {
            VStack(spacing: 0) {
                primaryAction
                moreButton
            }
        } else {
            HStack(spacing: 6) {
                moreButton
                primaryAction
            }
            .frame(minHeight: 44)
        }
    }

    private var moreButton: some View {
        Button { settings = true } label: { Image(systemName: "ellipsis") }
            .buttonStyle(WatchPetControlStyle())
            .accessibilityLabel("More options")
    }

    @ViewBuilder private var primaryAction: some View {
        if store.state.egg == nil {
            Button { showEggPicker = true } label: {
                Text(typeSize.isAccessibilitySize ? "Choose egg" : "Choose an egg")
                    .font(BatwalkFont.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .buttonStyle(BatwalkPrimaryButtonStyle())
            .accessibilityLabel("Choose an egg")
        } else if store.state.isEggReady {
            Button("Hatch") { page = 0 }
                .buttonStyle(BatwalkPrimaryButtonStyle())
        } else if needsStepHelp {
            Button { showStepAccess = true } label: {
                Text("Check Steps")
                    .font(BatwalkFont.caption)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .buttonStyle(BatwalkPrimaryButtonStyle())
        }
    }

    private var hasPrimaryAction: Bool {
        store.state.egg == nil || store.state.isEggReady || needsStepHelp
    }

    private var stepMessage: String? {
        guard !store.isDemo else { return nil }
        switch StepSyncCoordinator.shared.status {
        case .failed: return "Couldn't update steps."
        case .updated(let total, _): return total == 0 ? "No steps received today." : nil
        case .updating: return "Checking steps…"
        case .idle: return nil
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
