import SwiftUI
import BatwalkCore

/// A receipt uses the XP saved with the hatch, not today's rarity tuning.
struct ReunionDetailView: View {
    let record: HatchRecord
    private var duplicate: Bool { record.outcome == .duplicate }
    private var after: Int? {
        guard let before = record.friendshipBefore, let gained = record.friendshipGained else { return nil }
        return before + gained
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                BatHeroView(speciesID: record.speciesID, shiny: record.isShiny,
                            mood: .happy, size: 180, showsKeepsake: false)
                Text(record.hatchedAt.formatted(date: .abbreviated, time: .shortened))
                    .font(BatwalkFont.micro).foregroundStyle(BatwalkColor.textSecondaryLight)
                Text(duplicate ? "Hello again." : "A new little friend.")
                    .font(.system(.largeTitle, design: .serif)).multilineTextAlignment(.center)
                Text(Roster.species(record.speciesID)?.name ?? record.speciesID)
                    .font(BatwalkFont.body).foregroundStyle(BatwalkColor.textSecondaryLight)
                if duplicate, let gained = record.friendshipGained {
                    Label("+\(gained) XP", systemImage: "heart")
                        .font(BatwalkFont.rounded(.title, weight: .bold))
                    if let before = record.friendshipBefore, let after {
                        let oldLevel = Friendship.level(forEXP: before)
                        let newLevel = Friendship.level(forEXP: after)
                        Text(oldLevel == newLevel ? "Lv. \(newLevel)" : "Lv. \(oldLevel) → Lv. \(newLevel)")
                            .font(BatwalkFont.title)
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Total XP")
                                Spacer()
                                Text("\(before) → \(after)").monospacedDigit()
                            }
                            .font(BatwalkFont.caption)
                            FriendshipProgressView(exp: after, dark: false)
                        }
                        .batwalkLightCard()
                        Text(newLevel == Friendship.maxLevel
                             ? "Max level. Your total XP is kept."
                             : "Same bat. More XP. A closer friend.")
                            .font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryLight)
                    }
                } else if duplicate {
                    Text("This meeting was saved before XP receipts were added.")
                        .font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryLight)
                } else {
                    Label(record.outcome == .newShiny ? "Shiny discovered" : "Friend discovered", systemImage: "sparkle")
                        .font(BatwalkFont.headline)
                }
                NavigationLink { BatDetailPage(speciesID: record.speciesID) } label: {
                    Text("Meet your friend").frame(maxWidth: .infinity, minHeight: 44)
                }
                .buttonStyle(BatwalkPrimaryButtonStyle())
            }
            .foregroundStyle(BatwalkColor.textPrimaryLight)
            .padding(24)
            .frame(maxWidth: .infinity)
        }
        .background(BatwalkColor.lightBackground.ignoresSafeArea())
        .navigationTitle("A little meeting")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }
}
