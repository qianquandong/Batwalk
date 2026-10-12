import SwiftUI
import BatwalkCore

struct CompanionView: View {
    @Environment(GameStore.self) private var store
    @Environment(\.batPageVisible) private var pageVisible
    @Binding var tab: PhoneTab
    @State private var settings = false
    @State private var guide = DemoMode.scenario == "phone-guide"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    hero
                    VStack(alignment: .leading, spacing: 16) {
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
                            NavigationLink {
                                BatDetailPage(speciesID: bat.speciesID)
                            } label: {
                                Label("Little moments & friendship", systemImage: "play.circle")
                                    .font(BatwalkFont.headline).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }
                            Text("Your bat greets you in its own way when you open the Watch app. Closer friendship brings new habits; daytime is for sleepy little moments.")
                                .font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryLight)
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
                        HStack(spacing: 20) {
                            Label(store.state.fruit.formatted(), systemImage: "leaf")
                            Label(store.state.bankedSteps.formatted(), systemImage: "figure.walk")
                        }
                        .font(BatwalkFont.headline)
                        .accessibilityLabel("\(store.state.fruit) fruit, \(store.state.bankedSteps) steps saved for the next egg")
                        Text("Fruit · Steps saved for your next egg")
                            .font(BatwalkFont.micro).foregroundStyle(BatwalkColor.textSecondaryLight)
                        Button { tab = .batpedia } label: {
                            HStack { Text("Choose your Watch companion"); Image(systemName: "arrow.right") }
                                .font(BatwalkFont.headline).frame(maxWidth: .infinity, minHeight: 44)
                        }
                        NavigationLink { WatchGuideView() } label: {
                            Label("How to play & Watch help", systemImage: "book")
                                .font(BatwalkFont.body).frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                        }
                    }
                    .foregroundStyle(BatwalkColor.textPrimaryLight)
                    .padding(24)
                }
            }
            .background(BatwalkColor.lightBackground.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
            .sheet(isPresented: $settings) { PhoneSettingsView() }
            .sheet(isPresented: $guide) {
                NavigationStack {
                    WatchGuideView()
                        .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { guide = false } } }
                }
            }
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
                                    mood: BatMood.resting(at: time), size: 170,
                                    friendshipEXP: bat.friendshipEXP, showsKeepsake: false)
                        .environment(\.batPageVisible, pageVisible && !settings)
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
                    NavigationLink { WatchGuideView() } label: {
                        Label("How to play & Watch help", systemImage: "book")
                    }
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
                #if DEBUG
                Section("Preview") {
                    NavigationLink("Animation samples") { PilotAnimationLab() }
                }
                #endif
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

