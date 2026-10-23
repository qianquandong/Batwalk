import SwiftUI
import BatwalkCore

struct WeeklyRecapCard: View {
    let recap: WeeklyRecap
    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("BATWALK").font(.system(size: 12, weight: .bold, design: .rounded)).tracking(3)
            Text("A week of\nlittle hellos.").font(.system(size: 38, weight: .semibold, design: .serif))
            Text("WEEK \(recap.weekNumber)").font(.system(size: 12, weight: .semibold)).tracking(2)
            HStack(spacing: 9) { ForEach(Array(recap.symbols.enumerated()), id: \.offset) { _, symbol in Text(symbol.rawValue).font(.system(size: 27)) } }
            Text(recap.bats == 0 ? "An egg on the way." : "\(recap.bats) little meetings · \(recap.shiny) Shiny")
                .font(.system(size: 16, weight: .medium, design: .rounded))
            Spacer(minLength: 0)
        }
        .padding(32).frame(width: 400, height: 400, alignment: .topLeading)
        .foregroundStyle(BatwalkColor.textPrimaryLight).background(BatwalkColor.lightBackground)
    }
}

struct MonthlyChallengeCard: View {
    let challenge: MonthlyChallenge
    var body: some View {
        VStack(alignment: .leading, spacing: 13) {
            HStack { Text("BATWALK").tracking(3); Spacer(); Text(challenge.monthKey) }
                .font(.system(size: 11, weight: .bold, design: .rounded))
            Text(challenge.cosmetic.name).font(.system(size: 27, weight: .semibold, design: .serif))
                .lineLimit(1).minimumScaleFactor(0.65)
            HStack { Text(challenge.tier.title); Spacer(); Text("\(challenge.hatches) little meetings") }
                .font(.system(size: 13, weight: .medium, design: .rounded))
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 7) {
                ForEach(Array(["S", "M", "T", "W", "T", "F", "S"].enumerated()), id: \.offset) { _, day in Text(day).font(.system(size: 10, weight: .bold)).foregroundStyle(BatwalkColor.textSecondaryLight) }
                ForEach(0..<max(0, challenge.firstWeekday - 1), id: \.self) { _ in Color.clear.frame(height: 32) }
                ForEach(Array(challenge.symbols.enumerated()), id: \.offset) { day, symbol in
                    VStack(spacing: 0) { Text(symbol.rawValue).font(.system(size: 19)); Text("\(day + 1)").font(.system(size: 8)).foregroundStyle(BatwalkColor.textSecondaryLight) }
                }
            }
            Spacer(minLength: 0)
            Text("Every bat belongs in your collection, in every season.")
                .font(.system(size: 10, weight: .medium, design: .rounded))
        }
        .padding(28).frame(width: 400, height: 400).foregroundStyle(BatwalkColor.textPrimaryLight)
        .background(BatwalkColor.lightBackground)
    }
}

struct JournalCommunitySection: View {
    @Environment(GameStore.self) private var store
    private var now: Date { .now }
    private var recap: WeeklyRecap { .make(history: store.state.history, weekStart: SocialCalendar.recapStart(now)) }
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            if SocialCalendar.showsWeeklyRecap(now) || DemoMode.scenario == "phone-recap" {
                NavigationLink { WeeklyRecapView() } label: {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YOUR WEEK").font(BatwalkFont.micro).tracking(2)
                        Text(recap.symbolLine).font(.system(size: 24)).minimumScaleFactor(0.7).lineLimit(1)
                        Text(recap.bats == 0 ? "An egg on the way" : "\(recap.bats) little meetings").font(BatwalkFont.body)
                    }.frame(maxWidth: .infinity, alignment: .leading).padding(18)
                        .background(BatwalkColor.sage.opacity(0.13), in: RoundedRectangle(cornerRadius: 20))
                }.buttonStyle(.plain)
            }
            HStack(spacing: 18) {
                NavigationLink { WeeklyRecapView() } label: { Label("Week card", systemImage: "square.and.arrow.up") }
                NavigationLink { MonthlyChallengeView() } label: { Label("This month", systemImage: "sparkles") }
            }.font(BatwalkFont.caption).foregroundStyle(BatwalkColor.accent)
        }
    }
}

struct WeeklyRecapView: View {
    @Environment(GameStore.self) private var store
    @State private var image: Image?
    private var recap: WeeklyRecap { .make(history: store.state.history, weekStart: SocialCalendar.recapStart(.now)) }
    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                if let image {
                    image.resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 24))
                    SquareShareLink(image: image, title: "Batwalk · Week \(recap.weekNumber)")
                }
                ShareLink(item: recap.shareText) { Label("Share as text", systemImage: "text.bubble") }
                    .font(BatwalkFont.body)
                Text("No streaks to keep. Every week has a place here.").font(BatwalkFont.caption)
                    .foregroundStyle(BatwalkColor.textSecondaryLight)
            }.padding(24)
        }.background(BatwalkColor.lightBackground).navigationTitle("Your week")
            .navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
            .task(id: store.state.revision) { image = ShareCardRenderer.render(WeeklyRecapCard(recap: recap)) }
    }
}

struct MonthlyChallengeView: View {
    @Environment(GameStore.self) private var store
    @State private var image: Image?
    private var challenge: MonthlyChallenge { .make(state: store.state, monthKey: SocialCalendar.monthKey(.now)) }
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                if let image {
                    image.resizable().scaledToFit().clipShape(RoundedRectangle(cornerRadius: 24))
                    SquareShareLink(image: image, title: "Batwalk · \(challenge.monthKey)")
                }
                Text("A tiny outfit for this month's friends.").font(BatwalkFont.headline)
                Text("\(Tuning.challengeThresholds[.bronze]!) hatch wears it. \(Tuning.challengeThresholds[.silver]!) add a month stitch. \(Tuning.challengeThresholds[.gold]!) add a soft glow.")
                Text("It stays with the bats you meet this month. On Watch, open Options → Outfit to choose one. Every species can always be discovered; outfits never change eggs, odds or Friendship.")
                    .foregroundStyle(BatwalkColor.textSecondaryLight)
            }.font(BatwalkFont.body).padding(24)
        }.background(BatwalkColor.lightBackground).navigationTitle("This month")
            .navigationBarTitleDisplayMode(.inline).toolbar(.visible, for: .navigationBar)
            .task(id: store.state.revision) { image = ShareCardRenderer.render(MonthlyChallengeCard(challenge: challenge)) }
    }
}
