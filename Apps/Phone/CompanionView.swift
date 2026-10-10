import SwiftUI
import BatwalkCore

struct CompanionView: View {
    @Environment(GameStore.self) private var store
    @Binding var tab: PhoneTab
    @State private var settings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    VStack(alignment: .leading, spacing: 20) {
                        PhoneSyncStatus()
                        if let bat = store.state.companion {
                            Text("Growing together").font(BatwalkFont.title)
                            HStack(spacing: 14) {
                                Image(systemName: "heart.fill")
                                    .font(.title2).foregroundStyle(BatwalkColor.rose)
                                VStack(alignment: .leading, spacing: 8) {
                                    HStack {
                                        Text("Friendship").font(BatwalkFont.headline)
                                        Spacer()
                                        Text("Lv. \(Friendship.level(forEXP: bat.friendshipEXP))").font(BatwalkFont.caption)
                                    }
                                    FriendshipProgressView(exp: bat.friendshipEXP, dark: false)
                                }
                            }
                            .batwalkLightCard()
                        }
                        if let egg = store.state.egg {
                            VStack(alignment: .leading, spacing: 10) {
                                HatchProgressSummary(egg: egg, dark: false)
                                if egg.isReady {
                                    Label("Open Batwalk on your Watch to hatch.", systemImage: "applewatch")
                                        .font(BatwalkFont.caption).foregroundStyle(BatwalkColor.accent)
                                }
                            }
                            .batwalkLightCard()
                        } else if store.state.hasStarted {
                            Label("Pick your next egg on your Watch.", systemImage: "applewatch")
                                .font(BatwalkFont.caption)
                        }
                        if let request = store.companionHandoff.request,
                           store.companionHandoff.isWaiting || store.companionHandoff.failure != nil {
                            CompanionChangeControl(speciesID: request.speciesID)
                        }
                        if let error = store.lastError {
                            Text(error).font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryLight)
                        }
                        Text("Pet, feed and hatch on your Watch.")
                            .font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryLight)
                            .frame(maxWidth: .infinity)
                        Button { tab = .batpedia } label: {
                            HStack { Text("Meet your bats"); Image(systemName: "arrow.right") }
                                .font(BatwalkFont.headline).frame(maxWidth: .infinity, minHeight: 44)
                        }
                    }
                    .foregroundStyle(BatwalkColor.textPrimaryLight)
                    .padding(24)
                }
            }
            .background(BatwalkColor.lightBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $settings) { PhoneSettingsView() }
        }
    }

    private var hero: some View {
        TimelineView(.everyMinute) { context in
            let time = DemoMode.timeOfDay(at: context.date)
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("COMPANION").font(BatwalkFont.micro).tracking(2)
                        Text(store.state.companion?.companionTitle ?? "A little beginning")
                            .font(BatwalkFont.rounded(.largeTitle, weight: .bold))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    Button { settings = true } label: {
                        Image(systemName: "gearshape").font(.title2).frame(width: 44, height: 44)
                    }
                    .accessibilityLabel("Settings")
                }
                Group {
                    if let bat = store.state.companion {
                        BatHeroView(speciesID: bat.speciesID, shiny: bat.showsShiny,
                                    mood: BatMood.resting(at: time), size: 190,
                                    friendshipEXP: bat.friendshipEXP, showsKeepsake: false)
                        Label("Lv. \(Friendship.level(forEXP: bat.friendshipEXP))", systemImage: "heart.fill")
                            .font(BatwalkFont.headline)
                    } else {
                        EggSprite(type: store.state.egg?.type ?? .starter,
                                  state: store.state.egg?.visualState ?? .calm, size: 150)
                        Text(store.state.hasStarted ? "Your first friend is on the way." : "Your little world begins on your Watch.")
                            .font(BatwalkFont.caption).multilineTextAlignment(.center)
                    }
                }
                .frame(maxWidth: .infinity)
            }
            .foregroundStyle(BatwalkColor.cloud)
            .padding(24)
            .frame(maxWidth: .infinity)
            .background(NightSkyBackground(time: time, scenery: true, groundLevel: 0.88))
            .clipShape(UnevenRoundedRectangle(bottomLeadingRadius: 28, bottomTrailingRadius: 28))
        }
    }
}

struct PhoneSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showUnlock = DemoMode.scenario == "phone-unlock"

    var body: some View {
        NavigationStack {
            List {
                Section("Your little world") {
                    Button { showUnlock = true } label: {
                        Label("Full collection & purchases", systemImage: "sparkles")
                    }
                    NavigationLink { PrivacyView() } label: { Label("Privacy", systemImage: "hand.raised") }
                }
                Section("Watch connection") {
                    PhoneSyncStatus()
                    Text("Your Watch saves your progress. Keep both apps updated and open Batwalk on your Watch to refresh your collection.")
                        .font(BatwalkFont.caption)
                }
            }
            .scrollContentBackground(.hidden)
            .background(BatwalkColor.lightBackground)
            .navigationTitle("Settings")
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $showUnlock) {
                UnlockView()
                    .safeAreaInset(edge: .top) {
                        HStack { Spacer(); Button("Done") { showUnlock = false }.padding() }
                            .background(BatwalkColor.lightBackground)
                    }
            }
        }
        .tint(BatwalkColor.accent)
    }
}

