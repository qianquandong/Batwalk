# UI Redesign — completion report

Spec: [`UI_REDESIGN_TASKS.md`](UI_REDESIGN_TASKS.md) · Map: [`UI_REDESIGN_MAP.md`](UI_REDESIGN_MAP.md) ·
Boards: [`Art/ui-boards/`](../Art/ui-boards/)

Every screen below was captured from the **Watch (45 mm) and iPhone simulators** by the
`Screenshots` workflow (DemoMode scenarios), compared with the boards, and adjusted
over three rounds. The latest captures are on the `screenshots-output` branch.

## P12 — QA against the boards

**Watch**
- [x] Home — bat dominates (~55 % of height), moonlit sky with stars, moon, pines; glass card with name › and egg pill
- [x] Progress — gradient ring with % and egg, "961 steps to hatch", Today / Fruit rows on one screen
- [x] Friendship — bat, Lv., pink bar "20 / 100", Feed (n) button on one screen
- [x] Collection — 3 columns, glowing unlocked tiles with names and ♥, dark silhouette "?" tiles
- [x] Hatch Ready — "Ready!" title, glowing egg with sparkles, Hatch Now
- [x] Settings — companion, notifications, Health Access (Connected / Needs attention), restore, version

**iPhone**
- [x] Batpedia — "Batpedia · 1/20", Normal | Shiny pill, cards with rarity dot, lavender locked cards
- [x] Bat Detail — night hero, name ♥, Normal/Common chips, Friendship / Favourite Fruit / Hatch Source / Hatched, Set as Companion
- [x] History — 2×2 stat cards, Hatch Timeline with placeholders
- [x] Unlock — hero art, title, 5 benefits, "Unlock All Bats · $1.99 · One-time purchase", Restore
- [x] Collection Stats — progress ring hero, 5/10/15/20 milestones, Recent Hatches, See All

**System**
- [x] Typography: SF Rounded on Dynamic Type styles everywhere
- [x] Spacing: 4/8/12/16/24 grid (`BatwalkSpacing`)
- [x] Card radius: 14 / 16 / 18–24 by role (`BatwalkRadius`)
- [x] Colours centralised (`BatwalkColor`, `BatwalkGradient`) — no hex in screens except the paywall hero gradient
- [x] Motion subtle; stops off screen and in Always On
- [x] Reduce Motion: float, twitch, egg wiggle, ring pulse, sparkles, glows, slides off; fades kept
- [x] No broken functionality (independent code review + fixes; core unit tests green)

## Files

**New**
- `Apps/Shared/DesignSystem/BatwalkTheme.swift`, `BatwalkMotion.swift`, `BatwalkComponents.swift`
- `Apps/Watch/WatchComponents.swift`, `HatchViews.swift`, `SettingsView.swift`
- `Apps/Phone/PhoneComponents.swift`, `HistoryView.swift`, `UnlockView.swift`, `StatsView.swift`
- `scripts/phone-sim.sh`; `Art/ui-boards/*`; `docs/UI_REDESIGN_*.md`

**Rewritten / renamed**
- Watch: `RootView`, `HomeView`, `WalkView → ProgressPage`, `CareView → FriendshipPage`, `BatsView → CollectionPage`
- iPhone: `BatwalkPhoneApp`, `BatpediaView`; `HistoryAndUnlockViews` split into History / Unlock
- Shared: `Sprites` (BatHeroView, motion-aware EggSprite), `DemoMode` (moved to Shared, 21 scenarios), `PhoneSync` (iPhone → Watch command), `GameStore` (demo guard)
- Core: `Friendship.levelProgress`, `Species.favoriteFruit` (+ tests)
- CI: `screenshots.yml` + `capture-screens.sh` capture both platforms

## Reusable components

Shared: `BatwalkGlassCard`, `BatwalkLightCard`, `BatwalkPrimaryButtonStyle`, `PressableStyle`,
`BatwalkProgressRing`, `FriendshipProgressView`, `RarityChip`, `VariantChip`, `ChipView`, `EggIcon`,
`FruitIcon`, `BatSilhouette`, `NightSkyBackground`, `HeartBurst`, `SparkleField`, `BatwalkEmptyState`, `BatHeroView`.
Watch: `BatwalkStatRow`, `FeedButton`, `FruitToss`, `BatCollectionTile`, `LockedBatTile`, `HatchReadyView`, `HatchSequenceView`.
iPhone: `PhoneHeader`, `SegmentedPill`, `BatCard`, `LockedBatCard`, `StatCard`, `BatInfoRow`, `HatchHistoryRow`, `UndiscoveredRow`.

## Animations (P6)

| # | Motion | Implementation |
|---|---|---|
| 1 | Idle float | `IdleFloat`: ±1.5 pt, 2.4 s easeInOut, autoreverse |
| 2 | Ear twitch | `EarTwitch`: ±3° tilt 0.15 s / back 0.2 s, every 6–10 s (not while asleep) |
| 3 | Happy bounce | `HappyBounce`: scale 1.06, −3 pt, 0.35 s spring — pet, feed, wake |
| 4 | Progress ring | 0.7 s fill from previous value, 1.6 s pulse to 1.025 |
| 5 | Friendship bar | 0.5 s easeOut old → new |
| 6 | Hatch ready | 1.8 s glow loop, 5 twinkling sparkles |
| 7 | Tile unlock | `UnlockReveal`: 0 → 1 opacity, 0.9 → ~1.04 → 1 spring, brief glow |
| 8 | Button press | 0.96 scale, 0.1 s; spring release |
| 9 | Page appear | `BatwalkAppear`: fade + 12 pt slide, 0.3 s |
| — | Hatch sequence | dim 0.25 s → shake 0.4 s → crack 0.45 s → gold flash → reveal ≈ 2 s; Rare+/Shiny get stronger glow + extra haptic |
| — | Feed | fruit hops into bat → bounce + 4 hearts (< 1 s) |
| — | iPhone grid | 35 ms stagger, capped at 12 cards |

Haptics: feed/pet light · level-up success · egg ready notification · hatch strong · Rare/Legendary/Shiny one extra success. No navigation haptics.

## Remaining asset TODOs

- Mochi colour decision: boards draw Mochi **pink**; concept board draws Mochi **brown** (pink = Strawberry). Brown kept — swap is art-only.
- Full pixel-art sets for 16 species (currently recoloured Mochi), real Shiny palettes (currently hue shift), sleeping/eating poses at portrait resolution.
- Paywall treasure-chest hero art (TODO in `UnlockView.hero`).
- Fruit art set (interim 16×16 strawberry drawn in `build_sprites.py`).
- Lantern / forest scenery assets for the Watch Home (currently drawn with Canvas).

## Technical compromises

- Watch page transitions keep native vertical paging (custom transitions fight the Digital Crown); content does the fade + slide on appear.
- Ear twitch is a head tilt — sprites are single images with no separate ear layer.
- iPhone uses the system tab bar (tinted) rather than a custom floating bar; on iOS 26 it renders as the floating glass bar the board shows.
- iPhone "Set as Companion" is sent to the Watch (WatchConnectivity user-info) because the Watch is the only writer; the iPhone updates when the Watch syncs back.
- Health "Connected" means steps arrived today (HealthKit never reveals read denials).
- Feed's "fruit flies to bat" is a short hop from below the bat, not a path from the button.

## Build / test status

- `BatwalkCore` unit tests: green in CI (incl. new Friendship/fruit tests)
- Watch + iPhone simulator builds: green (Xcode 26.3, watchOS 26.2 / iOS 26 sims)
- Independent review: 10 findings, all fixed (purchase guard, Wake restored, cancellable hatch sequence, Always On motion, live Reduce Motion, Health status, Batpedia Normal filter, companion button reset, seen-bats seeding, CTA glow stop)
- Physical-device QA (P15): pending — install the TestFlight build and check haptics, animation feel and battery on the Watch.
