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
                        // The game's own progress first: the egg, then the bond.
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
                        if let bat = store.state.companion {
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
                                VStack(alignment: .leading, spacing: 4) {
                                    Label("Little moments & friendship", systemImage: "play.circle")
                                        .font(BatwalkFont.headline)
                                    Text("How \(bat.companionTitle) greets you on the Watch, and what closer friendship unlocks.")
                                        .font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryLight)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                            }
                        }
                        if let request = store.companionHandoff.request,
                           store.companionHandoff.isWaiting || store.companionHandoff.failure != nil {
                            CompanionChangeControl(speciesID: request.speciesID)
                        }
                        if let error = store.lastError {
                            Text(error).font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryLight)
                        }
                        // The pocket: what the next walk has to work with, labelled inline.
                        HStack(spacing: 16) {
                            Label { Text("\(store.state.fruit.formatted()) fruit") } icon: { FruitIcon(size: 18) }
                            Label("\(store.state.bankedSteps.formatted()) steps saved", systemImage: "figure.walk")
                        }
                        .font(BatwalkFont.caption)
                        .foregroundStyle(BatwalkColor.textSecondaryLight)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("\(store.state.fruit) fruit, \(store.state.bankedSteps) steps saved for the next egg")
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

    /// The scene is an inset card: the cream page stays continuous under the
    /// status bar and the dark sky reads as a window, not a wall. The level lives
    /// in the Friendship card below, not here as well.
    private var hero: some View {
        TimelineView(.everyMinute) { context in
            let time = DemoMode.timeOfDay(at: context.date)
            let companion = store.state.companion
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(companion == nil ? "FIRST EGG" : "COMPANION").font(BatwalkFont.micro).tracking(2)
                        Text(companion?.companionTitle ?? "A little beginning")
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
                    if let bat = companion {
                        BatHeroView(speciesID: bat.speciesID, shiny: bat.showsShiny,
                                    mood: BatMood.resting(at: time), size: 190,
                                    friendshipEXP: bat.friendshipEXP, showsKeepsake: false)
                        .environment(\.batPageVisible, pageVisible && !settings)
                        .padding(.bottom, 8)
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
            .padding(20)
            .frame(maxWidth: .infinity)
            .background(NightSkyBackground(time: time, scenery: true, groundLevel: 0.88))
            .clipShape(RoundedRectangle(cornerRadius: 28, style: .continuous))
            .padding(.horizontal, 16)
            .padding(.top, 8)
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

