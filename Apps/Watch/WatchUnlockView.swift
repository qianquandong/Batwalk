import SwiftUI
import BatwalkCore

/// The Watch paywall (2026-10-10 review: the Watch could only restore, never buy,
/// although it is the device a player holds when the free tier runs out).
/// One price, one button, no timers or fake discounts (PRD §2.10). Reached from
/// a locked egg, the Collection's "met every free bat" card and Settings.
struct WatchUnlockView: View {
    @Environment(GameStore.self) private var store
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.dismiss) private var dismiss

    private var remaining: Int { max(0, Roster.all.count - Roster.freeSpecies.count) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BatwalkSpacing.sm) {
                    HStack(alignment: .bottom, spacing: -10) {
                        BatSprite(speciesID: "moonwing", mood: .awake, size: 42)
                        BatSprite(speciesID: "strawberry", mood: .happy, size: 54)
                        BatSprite(speciesID: "galaxy", mood: .awake, size: 42)
                    }
                    .padding(.top, 2)
                    .accessibilityHidden(true)

                    Text(store.state.hasCompletedFreeRoster
                         ? "You've met all \(Roster.freeSpecies.count) free bats"
                         : "The full collection")
                        .font(BatwalkFont.headline)
                        .foregroundStyle(.white)
                        .multilineTextAlignment(.center)
                    Text("\(remaining) more bats, every egg, Rare, Legendary and Shiny — one purchase, forever.")
                        .font(BatwalkFont.micro)
                        .foregroundStyle(BatwalkColor.textSecondaryDark)
                        .multilineTextAlignment(.center)

                    if purchases.isUnlocked {
                        Label("Full unlock active", systemImage: "checkmark.seal.fill")
                            .font(BatwalkFont.caption)
                            .foregroundStyle(BatwalkColor.success)
                        Button("Done") { dismiss() }
                            .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 40))
                    } else {
                        Button {
                            Task { await purchases.purchase() }
                        } label: {
                            VStack(spacing: 1) {
                                Text("Unlock all bats")
                                Text(purchases.product?.displayPrice ?? (store.isDemo ? "$2.99" : "Loading price…"))
                                    .font(BatwalkFont.micro)
                                    .opacity(0.85)
                            }
                        }
                        .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 46))
                        .disabled(purchases.isBusy || (purchases.product == nil && !store.isDemo))
                        .doubleTapPrimaryAction()

                        if purchases.product == nil && !store.isDemo {
                            Button("Retry App Store") { Task { await purchases.loadProduct() } }
                                .font(BatwalkFont.micro)
                                .disabled(purchases.isLoadingProduct)
                        }
                        Button("Restore Purchase") { Task { await purchases.restore() } }
                            .font(BatwalkFont.micro)
                            .disabled(purchases.isBusy)
                    }

                    if let message = purchases.message {
                        Text(message).font(BatwalkFont.micro).foregroundStyle(BatwalkColor.textSecondaryDark)
                            .multilineTextAlignment(.center)
                    }
                    if let error = purchases.lastError {
                        Text(error).font(BatwalkFont.micro).foregroundStyle(BatwalkColor.warning)
                            .multilineTextAlignment(.center)
                    }
                    Text("Batwalk never sells steps or odds. Walking is the whole game.")
                        .font(BatwalkFont.micro)
                        .foregroundStyle(BatwalkColor.textSecondaryDark)
                        .multilineTextAlignment(.center)
                        .padding(.top, 2)
                }
                .padding(.horizontal, BatwalkSpacing.xs)
            }
            .navigationTitle("Unlock")
            .watchPageBackground()
        }
        .onChange(of: purchases.isUnlocked) { _, unlocked in
            if unlocked { Haptics.success() }
        }
    }
}
