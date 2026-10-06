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

## Getting started

Signing is preset to the **AI Man Jack LLC** team (`GB24TMUMQ5`, in `Config/Base.xcconfig`).

Requirements: a Mac with **Xcode 16+**, [XcodeGen](https://github.com/yonaskolb/XcodeGen), an Apple Watch on watchOS 10+ (or the simulator).

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

With automatic signing, Xcode registers the bundle IDs, App Group, iCloud container and HealthKit capability on the first device build — sign in to Xcode with the AI Man Jack LLC account. Only the in-app purchase must be created by hand in App Store Connect (until then, `Batwalk.storekit` covers testing):

| Thing | ID |
|---|---|
| iPhone app | `com.aimanjack.batwalk` |
| Watch app | `com.aimanjack.batwalk.watchkitapp` |
| Complication | `com.aimanjack.batwalk.watchkitapp.complication` |
| App Group | `group.com.aimanjack.batwalk` |
| iCloud container | `iCloud.com.aimanjack.batwalk` |
| In-app purchase (non-consumable) | `com.aimanjack.batwalk.fullunlock` |

Watch app capabilities: HealthKit (+ background delivery), iCloud/CloudKit, App Groups, Push Notifications.

If you change an identifier, change it in `project.yml` **and** `Apps/Shared/SharedConfig.swift`.

## How it works (one paragraph)

The Watch reads one number from HealthKit — today's cumulative Step Count — when
it becomes active and at most hourly in the background. `StepLedger` credits only
the increase since it last looked, so re-reading is always safe (midnight, DST,
force-quit, restore). Credited steps fill the current egg; extra steps are banked
for the next one. When an egg is full the Watch taps your wrist; you tap to hatch.
The outcome was fixed by a seed when the egg was created, so it can't be rerolled.
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
