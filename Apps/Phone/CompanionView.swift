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
                VStack(spacing: 20) {
                    HStack {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("YOUR LITTLE WORLD").font(BatwalkFont.micro).tracking(2)
                                .foregroundStyle(BatwalkColor.textSecondaryLight)
                            Text("A little closer.").font(.system(.title, design: .serif).weight(.semibold))
                        }
                        Spacer()
                        Button { settings = true } label: {
                            Image(systemName: "gearshape").font(.title2).frame(width: 44, height: 44)
                        }.accessibilityLabel("Settings")
                    }
                    .padding(.horizontal, 24)
                    hero
                    VStack(alignment: .leading, spacing: 16) {
                        PhoneSyncStatus()
                        eggSummary
                        if let record = store.state.history.last {
                            NavigationLink { ReunionDetailView(record: record) } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: record.outcome == .duplicate ? "heart" : "sparkle")
                                        .foregroundStyle(BatwalkColor.rose)
                                        .frame(width: 34, height: 34)
                                        .background(BatwalkColor.lightTint, in: Circle())
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(record.outcome == .duplicate ? "A familiar little face" : "A new little friend")
                                            .font(BatwalkFont.headline)
                                        if record.outcome == .duplicate, let xp = record.friendshipGained {
                                            Text("+\(xp) XP · See your progress").font(BatwalkFont.caption)
                                                .foregroundStyle(BatwalkColor.textSecondaryLight)
                                        }
                                    }
                                    Spacer(minLength: 0)
                                    Image(systemName: "chevron.right").font(BatwalkFont.micro)
                                }
                                .padding(.vertical, 8).frame(minHeight: 44)
                            }
                        }
                        if let request = store.companionHandoff.request,
                           store.companionHandoff.isWaiting || store.companionHandoff.failure != nil {
                            CompanionChangeControl(speciesID: request.speciesID)
                        }
                        if let error = store.lastError {
                            Text(error).font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryLight)
                        }
                        NavigationLink { WatchGuideView() } label: {
                            Label("Made for walks without your phone.", systemImage: "arrow.up.right")
                                .font(BatwalkFont.caption).frame(minHeight: 44, alignment: .leading)
                        }
                    }
                    .padding(.horizontal, 24).padding(.bottom, 24)
                }
                .padding(.top, 12)
                .foregroundStyle(BatwalkColor.textPrimaryLight)
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
            VStack(spacing: 10) {
                ZStack {
                    Circle().fill(BatwalkColor.moonlight.opacity(0.25)).frame(width: 230, height: 230)
                    Ellipse().fill(BatwalkColor.lightTint).frame(width: 300, height: 38).offset(y: 100)
                    if let bat = store.state.companion {
                        BatHeroView(speciesID: bat.speciesID, shiny: bat.showsShiny,
                                    mood: BatMood.resting(at: DemoMode.timeOfDay(at: context.date)), size: 250,
                                    friendshipEXP: bat.friendshipEXP, showsKeepsake: false)
                            .environment(\.batPageVisible, pageVisible && !settings && !guide)
                    } else {
                        EggSprite(type: store.state.egg?.type ?? .starter,
                                  state: store.state.egg?.visualState ?? .calm, size: 170)
                    }
                }
                .frame(height: 250).frame(maxWidth: .infinity)
                Text(store.state.companion?.companionTitle ?? "A little beginning")
                    .font(.system(.largeTitle, design: .serif)).multilineTextAlignment(.center)
                if let bat = store.state.companion {
                    Text("A familiar face. A little closer to you.")
                        .font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryLight)
                    NavigationLink { BatDetailPage(speciesID: bat.speciesID) } label: {
                        Label("Lv. \(Friendship.level(forEXP: bat.friendshipEXP)) · \(bat.friendshipEXP) XP", systemImage: "heart")
                            .font(BatwalkFont.caption).padding(.horizontal, 14)
                            .frame(minHeight: 44)
                            .background(BatwalkColor.lightCard, in: Capsule())
                            .overlay(Capsule().strokeBorder(BatwalkColor.lightTint, lineWidth: 1))
                    }
                } else {
                    Text("Your first friend is on the way.")
                        .font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryLight)
                }
            }
            .padding(.horizontal, 20)
        }
    }

    @ViewBuilder private var eggSummary: some View {
        if let egg = store.state.egg {
            Button { guide = true } label: {
                HStack(spacing: 14) {
                    EggIcon(type: egg.type, size: 40)
                    VStack(alignment: .leading, spacing: 7) {
                        Text(egg.isReady ? "Someone is ready to meet you" : "Someone new is on the way")
                            .font(BatwalkFont.headline)
                        Text(egg.isReady ? "Open Batwalk on your Watch" : "\(egg.creditedSteps.formatted()) / \(egg.targetSteps.formatted()) steps")
                            .font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryLight)
                        ProgressView(value: egg.progress).tint(BatwalkColor.accent)
                    }
                    Image(systemName: "chevron.right").font(BatwalkFont.micro)
                }
                .padding(16).background(BatwalkColor.lightTint, in: RoundedRectangle(cornerRadius: 22))
            }
        } else if store.state.hasStarted {
            Label("Pick your next egg on your Watch.", systemImage: "applewatch").font(BatwalkFont.caption)
        }
    }
}

struct PhoneSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var showUnlock = SharedConfig.paidContentEnabled && DemoMode.scenario == "phone-unlock"

    var body: some View {
        NavigationStack {
            List {
                Section("Your little world") {
                    NavigationLink { WatchGuideView() } label: {
                        Label("How to play & Watch help", systemImage: "book")
                    }
                    if SharedConfig.paidContentEnabled {
                        Button { showUnlock = true } label: {
                            Label("Cosmetics & purchases", systemImage: "sparkles")
                        }
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

