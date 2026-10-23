import SwiftUI
import BatwalkCore

/// The explanation belongs on the phone, where there is room to read it.
struct WatchGuideView: View {
    @Environment(GameStore.self) private var store

    var body: some View {
        List {
            Section("A little world on your wrist") {
                Label("Tap your bat to pet it. Tap Feed to give it a fruit.", systemImage: "hand.tap")
                Label("Swipe up or turn the Digital Crown to reach the egg page and check its progress.", systemImage: "circle.dotted")
                Text("When the egg is ready, tap Hatch or gently turn the Digital Crown. Choose the next egg after saying hello.")
            }
            Section("Personality, at its own pace") {
                Text("On opening the Watch app, your bat performs a familiar habit suited to its friendship and the time of day. It plays once per visit, then settles back into its routine.")
                Text("At Lv. 2, a small habit appears. At Lv. 3, petting or feeding gets a personal response. At Lv. 4, its signature moment joins the routine. Legendary secrets at Lv. 5 remain rare surprises.")
                Text("Some habits belong to daylight naps, some to dusk or night. A sleeping bat stays sleepy until you interact with it. Reduce Motion keeps a still pose.")
                Text("Your friendship never decreases. There is no hunger, punishment or streak to maintain.")
            }
            Section("Walking & fruit") {
                Text("Every \(Tuning.default.stepsPerFruit.formatted()) credited steps finds one fruit, up to \(Tuning.default.maxFruit) fruit. Feeding uses one fruit.")
                Text("Extra steps wait for the next egg, up to \(Tuning.default.maxBankedSteps.formatted()). Your Watch updates steps from Apple Health.")
                Text("Check saved steps and fruit on your Watch. Walking numbers stay on that device.")
            }
            Section("Eggs") {
                ForEach(EggType.allCases.filter(\.isPickable), id: \.self) { egg in
                    HStack(alignment: .top, spacing: 12) {
                        EggIcon(type: egg, size: 34).accessibilityHidden(true)
                        VStack(alignment: .leading, spacing: 5) {
                            Text(egg.displayName).font(BatwalkFont.headline)
                            Text("\(egg.targetSteps.formatted()) steps")
                            Text(egg.pool(isUnlocked: true).compactMap { Roster.species($0)?.name }.joined(separator: ", "))
                                .foregroundStyle(BatwalkColor.textSecondaryLight)
                        }
                    }
                }
                Text("All five eggs and every launch bat are free. Choose any egg in the Watch's Next egg picker. Each egg has its own pool; Shiny odds are the same for everyone.")
            }
            Section("Collection & levels") {
                Text("Choose a companion in Batpedia. Your Watch confirms the change; keep both apps open if a request is waiting.")
                Text("Hatching the same bat adds XP to the one you already own. More XP raises its level, up to Lv. 5. Common / Uncommon / Rare / Legendary duplicates give \(Tuning.default.duplicateEXP[.common] ?? 0) / \(Tuning.default.duplicateEXP[.uncommon] ?? 0) / \(Tuning.default.duplicateEXP[.rare] ?? 0) / \(Tuning.default.duplicateEXP[.legendary] ?? 0) XP. Total XP is kept after max level.")
                Text("For offline management, open the egg page on Watch, tap •••, then My bats. Nicknames and Shiny appearance remain available there.")
                if store.state.moonDust > 0 {
                    Text("Moon Dust saved in an earlier version is still yours. Use it in My bats on Watch; new duplicates only give XP.")
                }
            }
            Section("Step Count help") {
                Text("Before the first egg starts, tap Enable Steps on your Watch and allow Step Count. Batwalk starts after it receives steps. If you haven't walked yet today, walk a few steps, then tap Check again.")
                Text("If you dismissed the permission screen or turned Steps off, open Settings on your Watch → Health → Apps → Batwalk and turn on Steps. Return to Batwalk to check again. You can also manage access in iPhone Health → profile → Apps.")
                Text("Already playing? Tap Check Steps on the egg page when it appears, or open ••• → Step access → Update steps. Batwalk reads the Health data available on your Watch; the iPhone companion does not send phone step totals to it.")
                Text("Zero steps can mean no recorded walking or limited access; it does not prove permission was denied. Batwalk only reads Step Count and never writes to Health.")
                Text("Hatch and dusk alerts are optional. Change them in Watch → egg page → •••. If alerts are blocked, review notification permissions in device settings.")
            }
        }
        .font(BatwalkFont.body)
        .foregroundStyle(BatwalkColor.textPrimaryLight)
        .scrollContentBackground(.hidden)
        .background(BatwalkColor.lightBackground)
        .navigationTitle("Watch guide")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}
