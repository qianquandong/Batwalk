import SwiftUI
import BatwalkCore

/// Unlock (board: iPhone › 4. Unlock / Premium Paywall). One-time $1.99, no
/// subscription, no countdowns or fake discounts (PRD §2.10).
struct UnlockView: View {
    @Environment(PurchaseManager.self) private var purchases
    @Environment(GameStore.self) private var store
    private let ambient = AmbientMotionReader()

    @State private var ctaGlow = false
    @State private var celebrate = false

    private let benefits: [(String, String)] = [
        ("moon.stars.fill", "Access all \(Roster.all.count) bats"),
        ("star.fill", "Discover Rare & Legendary bats"),
        ("sparkles", "Find Shiny variants"),
        ("circle.hexagongrid.fill", "Unlock all egg pools"),
        ("book.closed.fill", "Complete the Batpedia"),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: BatwalkSpacing.md) {
                    hero

                    VStack(spacing: 6) {
                        Text("Unlock the Full\nBatwalk Experience")
                            .font(BatwalkFont.rounded(.title, weight: .bold))
                            .foregroundStyle(BatwalkColor.textPrimaryLight)
                            .multilineTextAlignment(.center)
                        Text("One purchase unlocks every bat and every egg — forever.")
                            .font(BatwalkFont.rounded(.subheadline))
                            .foregroundStyle(BatwalkColor.textSecondaryLight)
                            .multilineTextAlignment(.center)
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(benefits, id: \.1) { symbol, text in
                            HStack(spacing: 12) {
                                Image(systemName: symbol)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundStyle(BatwalkColor.purple)
                                    .frame(width: 28, height: 28)
                                    .background(Circle().fill(BatwalkColor.lightTint))
                                Text(text)
                                    .font(BatwalkFont.rounded(.subheadline, weight: .medium))
                                    .foregroundStyle(BatwalkColor.textPrimaryLight)
                                Spacer()
                            }
                        }
                    }
                    .batwalkLightCard(padding: 14, radius: 22)

                    if purchases.isUnlocked {
                        unlockedCard
                    } else {
                        Button {
                            Task { await purchases.purchase() }
                        } label: {
                            VStack(spacing: 2) {
                                Text("Unlock All Bats")
                                Text("\(purchases.product?.displayPrice ?? "$1.99") · One-time purchase")
                                    .font(BatwalkFont.rounded(.caption, weight: .medium))
                                    .opacity(0.9)
                            }
                        }
                        .buttonStyle(BatwalkPrimaryButtonStyle(minHeight: 58))
                        .shadow(color: BatwalkColor.purpleGlow.opacity(ctaGlow ? 0.55 : 0.2), radius: ctaGlow ? 14 : 6)
                        .disabled(purchases.isBusy || (purchases.product == nil && !store.isDemo))

                        if purchases.product == nil && !store.isDemo {
                            Text(purchases.lastError == nil ? "Connecting to the App Store…" : "The App Store isn't reachable right now.")
                                .font(BatwalkFont.caption)
                                .foregroundStyle(BatwalkColor.textSecondaryLight)
                        }
                    }

                    Button("Restore Purchase") { Task { await purchases.restore() } }
                        .font(BatwalkFont.rounded(.subheadline, weight: .semibold))
                        .disabled(purchases.isBusy)

                    if let error = purchases.lastError {
                        Text(error).font(BatwalkFont.caption).foregroundStyle(.red).multilineTextAlignment(.center)
                    }

                    Label("Thank you for supporting Batwalk!", systemImage: "heart.fill")
                        .font(BatwalkFont.caption)
                        .foregroundStyle(BatwalkColor.textSecondaryLight)
                        .padding(.bottom, BatwalkSpacing.sm)
                }
                .padding(BatwalkSpacing.lg)
            }
            .background(BatwalkColor.lightBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .task(id: ambient.allowed) {
            stopMotion { ctaGlow = false }
            guard ambient.allowed else { return }
            withAnimation(.easeInOut(duration: 1.6).repeatForever(autoreverses: true)) { ctaGlow = true }
        }
        .onDisappear { stopMotion { ctaGlow = false } }
        .onChange(of: purchases.isUnlocked) { _, unlocked in
            guard unlocked else { return }
            Haptics.success()
            withAnimation(BatwalkMotion.unlock) { celebrate = true }
        }
    }

    /// Hero: dusk sky with the board's four bats. TODO(asset): treasure-chest hero art from the iPhone board.
    private var hero: some View {
        ZStack {
            LinearGradient(colors: [Color(hex: 0x2A1F5C), Color(hex: 0x7B4FC9), Color(hex: 0xF0D6F5)],
                           startPoint: .top, endPoint: .bottom)
            NightSkyBackground(time: .night, scenery: false).opacity(0.35)
            SparkleField(count: 6, spread: 120)
            HStack(alignment: .bottom, spacing: -18) {
                BatSprite(speciesID: "moonwing", mood: .awake, size: 78)
                BatHeroView(speciesID: "mochi", mood: .happy, size: 124)
                BatSprite(speciesID: "galaxy", mood: .awake, size: 78)
            }
            .padding(.top, 20)
        }
        .frame(height: 190)
        .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
        .accessibilityHidden(true)
    }

    private var unlockedCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(BatwalkGradient.primary)
                .scaleEffect(celebrate ? 1 : 0.85)
            Text("Unlocked — thank you!")
                .font(BatwalkFont.headline)
                .foregroundStyle(BatwalkColor.textPrimaryLight)
            Text("Every bat and egg is now waiting on your walks.")
                .font(BatwalkFont.caption)
                .foregroundStyle(BatwalkColor.textSecondaryLight)
        }
        .frame(maxWidth: .infinity)
        .batwalkLightCard(padding: 20, radius: 22)
        .overlay { if celebrate { SparkleField(count: 6, color: BatwalkColor.purple, spread: 90) } }
    }
}
