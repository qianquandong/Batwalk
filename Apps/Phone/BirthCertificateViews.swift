import SwiftUI
import BatwalkCore

/// One share affordance throughout the phone, always backed by the system sheet.
struct SquareShareLink: View {
    let image: Image
    let title: String
    var label = "Share card"
    var body: some View {
        ShareLink(item: image, preview: SharePreview(title, image: image)) {
            Label(label, systemImage: "square.and.arrow.up")
                .font(BatwalkFont.headline).frame(minHeight: 44)
        }
        .accessibilityLabel("Share \(title)")
    }
}

@MainActor
enum ShareCardRenderer {
    static func render<Content: View>(_ content: Content) -> Image? {
        let renderer = ImageRenderer(content: content.environment(\.colorScheme, .light)
            .environment(\.dynamicTypeSize, .medium))
        renderer.scale = 3
        guard let image = renderer.uiImage else { return nil }
        return Image(uiImage: image)
    }
}

struct SquareShareCardPreview<Content: View>: View {
    @ViewBuilder var content: () -> Content
    var body: some View {
        GeometryReader { geometry in
            content().environment(\.colorScheme, .light).environment(\.dynamicTypeSize, .medium)
                .scaleEffect(geometry.size.width / 400, anchor: .topLeading)
        }
        .aspectRatio(1, contentMode: .fit)
        .clipShape(RoundedRectangle(cornerRadius: 22))
        .accessibilityElement(children: .combine)
    }
}

/// Fixed 400 point layout renders to a 1200 × 1200 collectible.
struct BirthCertificateCard: View {
    let record: HatchRecord
    let nickname: String?
    let ordinal: Int?
    let showSteps: Bool
    var outfit: ChallengeOutfit? = nil
    private var species: Species? { Roster.species(record.speciesID) }
    private let ink = Color(red: 0.20, green: 0.28, blue: 0.25)
    private let paper = Color(red: 0.96, green: 0.93, blue: 0.86)

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text("BATWALK").font(.system(size: 12, weight: .heavy, design: .rounded)).tracking(2)
                Spacer()
                Text(record.birthdayYear.map { "BIRTHDAY · \($0)" } ?? "A LITTLE ARRIVAL").font(.system(size: 8, weight: .semibold)).tracking(1.5)
            }
            Rectangle().fill(ink.opacity(0.16)).frame(height: 1)
            HStack(alignment: .top) {
                Text(String(format: "No. %02d", species?.number ?? 0)).font(.system(size: 10, weight: .medium))
                Spacer()
                if let ordinal { Text("Your \(Self.ordinal(ordinal)) bat").font(.system(size: 10, weight: .medium)) }
            }
            ZStack {
                Circle().fill(Color.white.opacity(0.45)).frame(width: 118, height: 118)
                BatSprite(speciesID: record.speciesID, shiny: record.isShiny, mood: .happy, size: 134)
                    .overlay { ChallengeOutfitOverlay(outfit: outfit) }
                    .overlay { BirthdayHatOverlay(speciesID: record.speciesID, year: record.birthdayYear, mood: .happy) }
                if record.isShiny {
                    Image(systemName: "sparkles").font(.system(size: 24)).foregroundStyle(Color.orange.opacity(0.8))
                        .offset(x: 76, y: -44)
                }
            }
            .frame(height: 120)
            Text(nickname ?? species?.name ?? "A little friend")
                .font(.system(size: 25, weight: .semibold, design: .serif)).lineLimit(1).minimumScaleFactor(0.6)
            if nickname != nil { Text(species?.name ?? "").font(.system(size: 10)).opacity(0.7) }
            HStack(spacing: 8) {
                Text(species?.rarity.displayName ?? "Bat").textCase(.uppercase)
                Text("·")
                Text(record.source == .moonDust ? "Moon Dust" : record.certificateEggName)
                if record.isShiny { Text("· Shiny") }
            }
            .font(.system(size: 10, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
            if showSteps, let steps = record.eggSteps, let days = record.certificateDays() {
                Text("\(steps.formatted()) steps · \(days) \(days == 1 ? "day" : "days") together")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
            }
            Text("\(MoonPhase.on(record.hatchedAt).symbol)  \(MoonPhase.on(record.hatchedAt).name)")
                .font(.system(size: 11)).opacity(0.8)
            Text(species?.realLifeCousin ?? species?.hook ?? "A small friend for everyday walks.")
                .font(.system(size: 10)).multilineTextAlignment(.center).lineLimit(3)
                .frame(maxWidth: .infinity).padding(.horizontal, 12)
            Spacer(minLength: 0)
            HStack {
                Text(record.hatchedAt.formatted(date: .abbreviated, time: .omitted))
                Spacer()
                Text(record.isShiny ? "\(Int((Tuning.default.shinyChance * 100).rounded()))% base Shiny chance" : "A walk worth remembering")
            }
            .font(.system(size: 8, weight: .medium)).opacity(0.7)
        }
        .foregroundStyle(ink).padding(22)
        .frame(width: 400, height: 400)
        .background(paper)
        .overlay(Rectangle().strokeBorder(ink.opacity(0.22), lineWidth: 1).padding(10))
    }

    static func ordinal(_ value: Int) -> String {
        let suffix: String
        if (11...13).contains(value % 100) { suffix = "th" }
        else { suffix = [1: "st", 2: "nd", 3: "rd"][value % 10] ?? "th" }
        return "\(value)\(suffix)"
    }
}

struct BirthCertificateView: View {
    @Environment(GameStore.self) private var store
    @AppStorage("shareCardShowsSteps") private var showSteps = true
    let record: HatchRecord
    @State private var metrics: CertificateMetrics?
    @State private var loading = false
    @State private var message: String?
    @State private var image: Image?

    private var resolved: HatchRecord { metrics?.applying(to: record) ?? record.withoutActivityMetrics }
    private var nickname: String? { store.state.collection[record.speciesID]?.nickname }
    private var recordIndex: Int? { store.state.history.lastIndex(of: record) }
    // A trimmed backup cannot reconstruct the original ordinal. Never invent one.
    private var ordinal: Int? {
        guard record.source == .egg, let index = recordIndex,
              store.state.history.count == store.state.collection.values.reduce(0, { $0 + $1.hatchCount }) else { return nil }
        return store.state.history.prefix(index + 1).filter { $0.source == .egg }.count
    }
    private var card: BirthCertificateCard {
        BirthCertificateCard(record: resolved, nickname: nickname, ordinal: ordinal, showSteps: showSteps,
            outfit: store.state.earnedOutfits(for: record.speciesID).first {
                $0.monthKey == (record.challengeMonthKey ?? SocialCalendar.monthKey(record.hatchedAt))
            })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SquareShareCardPreview { card }
                if let image { SquareShareLink(image: image, title: "Batwalk birth certificate") }
                Toggle("Show steps on this card", isOn: $showSteps)
                if showSteps, record.source == .egg, metrics == nil {
                    Text("Steps and days stay on your Watch. Include them in this card only when you choose. Both apps need to be open.")
                        .font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryLight)
                    Button(loading ? "Asking your Watch…" : "Include my steps and days") { requestMetrics() }
                        .disabled(loading).frame(minHeight: 44)
                }
                if let message { Text(message).font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryLight) }
                if record.outcome == .duplicate {
                    NavigationLink { ReunionDetailView(record: record) } label: {
                        Label("Friendship from this hello", systemImage: "heart")
                    }
                }
                Text("Moon phase is an offline estimate. Shiny cards show the base odds; friendship and the guarantee can improve them.")
                    .font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryLight)
            }
            .padding(24)
        }
        .background(BatwalkColor.lightBackground.ignoresSafeArea())
        .navigationTitle("Birth certificate").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar).toolbar(.hidden, for: .tabBar)
        .task {
            // Screenshot fixtures only; real receipts are requested by the explicit button.
            if store.isDemo, let start = record.eggStartedAt, let steps = record.eggSteps {
                metrics = CertificateMetrics(eggStartedAt: start, eggSteps: steps)
            }
            render()
        }
        .onChange(of: showSteps) { _, enabled in
            if !enabled { metrics = nil }
            render()
        }
        .onChange(of: metrics) { _, _ in render() }
    }

    private func render() { image = ShareCardRenderer.render(card) }
    private func requestMetrics() {
        guard let index = recordIndex else { message = "This older walk has no saved details."; return }
        loading = true; message = nil
        let request = CertificateMetricsRequest(saveID: store.state.saveID, recordIndex: index,
                                                speciesID: record.speciesID, hatchedAt: record.hatchedAt)
        PhoneSync.shared.requestCertificateMetrics(request) { result in
            loading = false
            switch result {
            case .success(let value):
                if showSteps { metrics = value }
            case .failure(.missingReceipt): message = "This older walk has no saved steps or start date. Its certificate is still yours to share."
            case .failure(.unavailable): message = "Open Batwalk on your paired Watch, then try again. You can also share without walk details."
            }
        }
    }
}

struct CollectionPosterCard: View {
    let state: GameState
    private var species: [Species] { Roster.all.filter { $0.number <= 20 }.sorted { $0.number < $1.number } }
    private var owned: Int { species.filter { state.collection[$0.id] != nil }.count }
    private var shiny: Int { species.filter { state.collection[$0.id]?.hasShiny == true }.count }
    var body: some View {
        VStack(spacing: 10) {
            Text("BATWALK").font(.system(size: 12, weight: .heavy, design: .rounded)).tracking(3)
            Text("Our little world").font(.system(size: 28, weight: .semibold, design: .serif))
            // Eager rows are required for ImageRenderer: lazy grids may never
            // materialize their children in an off-screen export.
            VStack(spacing: 8) {
                ForEach(0..<4, id: \.self) { row in
                    HStack(spacing: 6) {
                        ForEach(Array(species.dropFirst(row * 5).prefix(5))) { species in
                            VStack(spacing: 2) {
                                if let bat = state.collection[species.id] {
                                    BatSprite(speciesID: species.id, shiny: bat.showsShiny, mood: .awake, size: 40)
                                        .overlay { BirthdayHatOverlay(speciesID: species.id, year: bat.birthdayYears?.max()) }
                                } else {
                                    BatSilhouette(size: 40, color: Color(red: 0.65, green: 0.69, blue: 0.61))
                                }
                                Text(String(format: "%02d", species.number)).font(.system(size: 8, weight: .medium))
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            Text("\(owned) / 20 bats · \(shiny) Shiny").font(.system(size: 15, weight: .semibold, design: .rounded))
            Text("Little friends, found along the way.").font(.system(size: 10))
        }
        .foregroundStyle(Color(red: 0.20, green: 0.28, blue: 0.25)).padding(24)
        .frame(width: 400, height: 400)
        .background(Color(red: 0.96, green: 0.93, blue: 0.86))
    }
}

struct CollectionPosterView: View {
    @Environment(GameStore.self) private var store
    @State private var image: Image?
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                SquareShareCardPreview { CollectionPosterCard(state: store.state) }
                if let image { SquareShareLink(image: image, title: "My Batwalk collection") }
                Text("Your first 20 friends, with a little space for the ones still on their way.")
                    .font(BatwalkFont.caption).foregroundStyle(BatwalkColor.textSecondaryLight)
            }.padding(24)
        }
        .background(BatwalkColor.lightBackground.ignoresSafeArea())
        .navigationTitle("Collection poster").navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar).toolbar(.hidden, for: .tabBar)
        .task { image = ShareCardRenderer.render(CollectionPosterCard(state: store.state)) }
    }
}
