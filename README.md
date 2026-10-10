<p align="center"><img src="Art/icon-placeholder.png" width="128" alt="Batwalk placeholder icon"></p>

# Batwalk

**A tiny bat that lives on your wrist and grows when you move.**

Batwalk turns everyday walking into a cozy collectible-pet loop on Apple Watch.
Your steps hatch eggs, eggs hatch bats, bats become your companion. The Watch is
the game; the iPhone is the companion library.

- 🦇 20 bat species · Normal + Shiny variants · Friendship Lv.1–5
- 🥚 5 egg types (2,000 – 6,000 steps)
- 🌙 Day / Dusk / Night behaviour from local time
- 💤 No death, no hunger, no streaks, no guilt — ever
- 💵 Free + one-time $1.99 unlock · no AI · no backend

📄 **[Product Requirements (PRD v1.0)](docs/PRD.md)** · [Roadmap](docs/ROADMAP.md) · [Open questions](docs/OPEN_QUESTIONS.md) · [Test plan](docs/TEST_PLAN.md) · [Decisions](docs/decisions/)

---

## Repo layout

```
Packages/BatwalkCore/   Pure-Swift game rules + unit tests (no UI, no HealthKit)
  Species.swift           20-bat roster, rarities, free tier
  EggType.swift           egg targets + hatch pools
  HatchEngine.swift       seeded rarity/species/Shiny roll
  StepLedger.swift        HealthKit daily totals → exactly-once step credit
  GameState.swift         the save: eggs, collection, Friendship, fruit, history
  Presentation.swift      Day/Dusk/Night, egg visual states, Friendship levels
  Tuning.swift            every balance number in one place
Apps/Watch/             The game (SwiftUI, HealthKit, haptics)
Apps/Complication/      WidgetKit Watch-face complication
Apps/Phone/             Batpedia, Large View, History, Unlock/Restore
Apps/Shared/            Persistence (SwiftData+CloudKit), sync, StoreKit, sprites
Config/                 xcconfig + local StoreKit test config
Art/                    Art direction + sprite naming contract
docs/                   PRD, roadmap, open questions, ADRs, test plan
project.yml             XcodeGen spec (the .xcodeproj is generated, not committed)
```

## No Mac? Build and preview with Codemagic

The manual workflows in [`codemagic.yaml`](codemagic.yaml) run Watch/iPhone checks
and capture Watch simulator screenshots on a Codemagic Mac, independently of
GitHub Actions. No Apple signing credentials are needed for these simulator builds.
See **[Codemagic setup](docs/CODEMAGIC.md)** to connect this private repository and
select the branch containing the configuration. A local Codex monitor can start
the verification workflow when GitHub explicitly blocks CI for billing or minute
limits; its operating requirements are documented in the same guide.

## Ship to TestFlight from your phone

`.github/workflows/testflight.yml` archives, cloud-signs and uploads the app on
GitHub's macOS runners. One-time setup (all doable in a phone browser):

1. **App Store Connect › Users and Access › Integrations › App Store Connect API** → generate a *Team key* with the **Admin** role. Download the `.p8` (only possible once) and note the **Key ID** and **Issuer ID**.
2. **GitHub › repo Settings › Secrets and variables › Actions** → add `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_KEY_P8` (the whole `.p8` text).
3. Follow **[Signing](docs/SIGNING.md)** to register App Groups and the iCloud container in the developer portal. An App Store Connect API key does not perform that setup. Run **TestFlight** with *upload* **off** to validate the signed archive first.
4. **App Store Connect › Apps › + New App** → iOS, bundle ID `com.aimanjack.batwalk`, SKU `batwalk`.
5. Run the workflow again with *upload* **on** (or push to the `testflight` branch). Install from the **TestFlight** app on iPhone; the Watch app installs to the paired Apple Watch.

## Getting started (with a Mac)

Signing is preset to the **AI Man Jack LLC** team (`GB24TMUMQ5`, in `Config/Base.xcconfig`).

Requirements: a Mac with **Xcode 26+** (CI currently uses stable Xcode 26.3), [XcodeGen](https://github.com/yonaskolb/XcodeGen), an Apple Watch on watchOS 10+ (or the simulator).

```bash
git clone https://github.com/qianquandong/batwalk.git
cd batwalk
brew install xcodegen

# 1. Run the rules' tests — no Xcode project needed
swift test --package-path Packages/BatwalkCore

# 2. Generate and open the Xcode project
xcodegen generate
open Batwalk.xcodeproj
```

Pick the **BatwalkWatch** scheme to run the game on a Watch simulator or device.
The **BatwalkPhone** scheme runs the companion and uses `Config/Batwalk.storekit`,
so the $1.99 unlock can be tested without App Store Connect.

### Before running on real devices

Sign in to Xcode with the AI Man Jack LLC account. Register the capabilities described in [Signing](docs/SIGNING.md) before enabling them. The default project keeps live widget sharing and cloud backup disabled until that setup is complete. Create the in-app purchase in App Store Connect; `Batwalk.storekit` covers local testing:

| Thing | ID |
|---|---|
| iPhone app | `com.aimanjack.batwalk` |
| Watch app | `com.aimanjack.batwalk.watchkitapp` |
| Complication | `com.aimanjack.batwalk.watchkitapp.widget` |
| App Group | `group.com.aimanjack.batwalk` |
| iCloud container | `iCloud.com.aimanjack.batwalk` |
| In-app purchase (non-consumable) | `com.aimanjack.batwalk.fullunlock` |

Watch app capabilities: HealthKit (+ background delivery), iCloud/CloudKit, App Groups, Push Notifications.

If you change an identifier, change it in `project.yml` **and** `Apps/Shared/SharedConfig.swift`.

## How it works (one paragraph)

The Watch reads daily cumulative Step Count in one HealthKit batch on foreground
and system-delivered background updates (requested hourly, delivery is not guaranteed).
It reconciles the last seven days plus any unprocessed absence, credits each positive
daily increase once, and retries a failed batch without advancing past it. Accounting
keeps its original time zone across travel to avoid splitting the same steps twice.
Collection restore starts a fresh daily baseline. Credited steps fill the current egg; extra steps are banked
for the next one. When an egg is full the Watch taps your wrist; you tap to hatch.
The species and variant are sealed when the egg is created, so purchases, refunds,
and later tuning changes cannot reroll it. Complete step saves are local; the optional
private CloudKit backup contains collection metadata only.

See [release readiness and remaining device checks](docs/RELEASE_READINESS.md).
Duplicates turn into Friendship EXP. The whole game state is one Codable value,
saved by the Watch to SwiftData, mirrored to iCloud, and pushed to the iPhone.
See [ADR 0001](docs/decisions/0001-architecture.md).

## Status

**M0 — Foundation.** Every PRD mechanic is implemented in `BatwalkCore` with
tests, and every Watch / iPhone screen is wired to it using vector placeholder
art. Next: run on a physical Watch and integrate pixel art — see the
[roadmap](docs/ROADMAP.md).

## Product guardrails (from the PRD — don't break these)

- The core loop must work with the iPhone left at home.
- Never sell steps, odds, energy, or Friendship. The unlock is content only.
- No punishment mechanics of any kind.
- Read only Step Count; never upload Health data.
- No AI features.
