# Batwalk — Final Product Requirements Document

> **A tiny bat that lives on your wrist and grows when you move.**
>
> Batwalk turns everyday walking into a cozy collectible-pet loop on Apple Watch.
> The Watch is the game. The iPhone is the companion library and data viewer.

| Status | Primary platform | Language | Monetization |
|---|---|---|---|
| Final PRD v1.0 | Apple Watch | English only | Free + $1.99 unlock |

**Contents** — [Locked Decisions](#locked-product-decisions) · [1. Discovery](#1-discovery--problem--opportunity) · [2. Design](#2-design--solution-shape) · [3. Art Direction](#3-art-direction--production-spec) · [4. Build](#4-build--technical-implementation) · [5. Launch](#5-launch--deploy--operate) · [6. Content](#6-launch-content--20-bat-roster) · [7. Scope Lock](#7-mvp-scope-lock) · [8. Definition of Done](#8-mvp-definition-of-done)

> Where this document is ambiguous or self-contradictory, see [OPEN_QUESTIONS.md](OPEN_QUESTIONS.md) for how the code currently resolves it.

---

## Locked Product Decisions

| Area | Decision |
|---|---|
| Working title | Batwalk |
| Core platform | Apple Watch-first; iPhone companion is optional for core gameplay |
| Visual style | Polished 2D pixel art |
| Mood | Cute + cozy + slightly mysterious; never horror-first |
| Launch roster | 20 bat species |
| Hatching cadence | Typically 1–2 bats/day; no hard daily cap |
| Duplicates | Allowed; duplicates add Friendship EXP instead of creating junk inventory copies |
| Companion | One current companion shown on Watch at a time |
| Naming | Players can rename their owned companion |
| Day/night | Based on local device time: Day / Dusk / Night |
| Feeding | Included; fruit rewards add interaction and Friendship. No hunger punishment. |
| Language | English only at launch |
| Pricing | Free download; $1.99 one-time purchase unlocks full content |
| Free tier | 3 bats + 2 egg types + complete core hatching/care loop |
| Save | Local-first + iCloud/CloudKit backup/restore |
| Notifications | Only lightweight events such as Hatch Ready / Bat Awake |
| AI | **None.** No AI features, AI roadmap, or AI positioning |
| Punishment | No death, starvation, streak loss, guilt messaging, or level decay |

---

## 1. Discovery — Problem & Opportunity

### 1.1 Problem

Most activity products motivate users through steps, calories, streaks, rings, and goals. Those systems work for fitness-motivated users, but for casual users they often feel like another obligation.

At the same time, most virtual-pet games live on the phone and require deliberate sessions. Apple Watch creates a different opportunity: a tiny pet that is physically present on the wrist and reacts to the user's real-world movement.

> *"My egg is only 600 steps away from hatching."* is a stronger emotional prompt than *"I still need 600 steps today."*

### 1.2 Target Users

| User | Primary Goal | Constraint |
|---|---|---|
| Casual Apple Watch owner | Have a fun reason to move more | Does not want a serious fitness app |
| Cozy-game player | Care for a cute persistent companion | Short interaction windows |
| Collector | Find Rare, Legendary, and Shiny bats | Needs long-term collection goals |
| Existing fitness user | Add delight to normal walking | Does not want extra workout friction |

### 1.3 Core Pain Points

1. **Movement lacks emotional reward.** Raw numbers do not create attachment.
2. **Phone games require deliberate attention.** Batwalk should work in 3–10 second glances.
3. **Many Watch apps are reduced phone apps.** Batwalk is designed from the Watch outward.

### 1.4 Goals

- **Daily loop** — See bat → see progress → walk → return → receive a reward.
- **Movement becomes progression** — Steps directly affect egg hatching, collection, Friendship, and unlocks.
- **Emotional ownership** — The user should feel "this is my bat," not "this is a step counter skin."
- **Watch independence** — The core experience must remain playable without opening the iPhone app.

### 1.5 Non-goals for MVP

Deferred: GPS map, AR, trading, friends, guilds, leaderboards, battles, breeding, complex currency, subscriptions, energy systems, advanced habitat economy, weather-driven gameplay, real ambient-light detection.

---

## 2. Design — Solution Shape

### 2.1 Core Product

Batwalk is a Watch-first virtual-pet collection game. The user's real-world walking advances eggs, unlocks bats, and contributes to a light Friendship system. The iPhone companion app exists for deeper viewing, Batpedia, history, purchases, and recovery — not to gate the core loop.

```
WALK → EGG PROGRESS → ANTICIPATION → HATCH → COLLECT
  ↑                                              ↓
WALK AGAIN ← NEW EGG ← BUILD FRIENDSHIP ← CHOOSE CURRENT COMPANION
```

### 2.2 First-Time User Flow

1. Launch on Apple Watch.
2. Dark screen: "Something is sleeping in here..."
3. An egg appears.
4. Message: "Your steps help it hatch."
5. Ask for Step Count permission.
6. Read already-earned steps from today and credit them immediately.
7. Starter Egg target: 2,000 steps.
8. At 100%, Watch haptic + "Ready to hatch."
9. User taps to hatch entirely on Watch.
10. First bat joins Collection and becomes current companion.

### 2.3 Day / Dusk / Night

| Time State | Recommended Window | Bat Behavior |
|---|---|---|
| Day | 7:00 AM–6:00 PM | Sleeping, yawning, peeking, quiet interactions |
| Dusk | 6:00 PM–7:00 PM | Waking, stretching, opening one eye |
| Night | 7:00 PM–7:00 AM | Flying, playing, more energetic reactions |

> **Important:** Daytime is not a lockout. Day = companionship. Night = activity.

### 2.4 Watch Navigation

| Screen | Purpose |
|---|---|
| **HOME** | Current bat or current egg. This is where most time is spent. |
| **WALK** | Today's steps and egg progress. Game progress first, fitness data second. |
| **CARE** | Feed, pet, wake, and short reactions. |
| **BATS** | Compact collection grid and current companion selector. |

### 2.5 iPhone Companion MVP

- **Batpedia** — full-size bat art, species, rarity, hatch history, Friendship.
- **Collection** — owned, missing, Normal/Shiny status.
- **Large View** — presentation-quality bat view for screenshots.
- **Basic History** — hatch milestones and simple activity history.
- **Purchase / Restore Purchase.**

Habitat is deferred beyond MVP unless schedule permits.

### 2.6 Egg System

| Egg | Target Steps | Purpose |
|---|---|---|
| Starter Egg | 2,000 | Fast first success |
| Tiny Egg | 2,500 | Quick everyday hatch |
| Forest Egg | 4,000 | Nature-themed pool |
| Moon Egg | 5,000 | Night / Rare pool |
| Crystal Egg | 6,000 | Higher-end Rare pool |

Normal players should typically hatch 1–2 bats per day. No hard cap is required.

### 2.7 Duplicate & Friendship System

Duplicates are allowed, but the Collection does not accumulate piles of identical copies. A duplicate converts into Friendship EXP for that species.

| Friendship Level | Unlock |
|---|---|
| Lv.1 | Base animation set |
| Lv.2 | Additional idle animation |
| Lv.3 | New interaction reaction |
| Lv.4 | Special signature animation |
| Lv.5 | Friendship badge + special expression/accessory |

### 2.8 Feeding

Walking can occasionally yield simple fruit rewards such as berries or strawberries. Feeding produces a short reaction and contributes modest Friendship progress.

**No hunger system.** A bat never dies, starves, loses levels, or punishes the player for taking a break.

### 2.9 Shiny System

Every species can have a Normal and Shiny variant. Shiny is a palette/visual variant, not a separate species entry.

Example: Moonwing → Normal ✅ / Shiny ⬜. Twenty species therefore create up to forty meaningful visual collection targets.

### 2.10 Monetization

| Tier | Contents | Price |
|---|---|---|
| Free | 3 bat species, 2 egg types, full basic hatch/care/Friendship loop | $0 |
| Full Unlock | All 20 bats, all egg pools, Rare/Legendary/Shiny access, full Friendship progression | $1.99 one-time |

> **Never** sell step skips, better hatch odds, energy, Friendship boosts, or any shortcut that undermines walking.

---

## 3. Art Direction & Production Spec

> **Approved visual direction.** The Batwalk concept board is the approved visual reference for MVP production. Character proportions, palette mood, pixel density, Watch presentation, day/night behavior, and animation tone should all derive from this board.
>
> ![Batwalk concept board](../Art/concept-board.png)

### 3.1 Visual Language

- **Style:** polished 2D pixel art, not retro-low-detail pixel art.
- **Shape language:** round bodies, readable ears, oversized expressive eyes, clear wing silhouettes.
- **Mood:** cozy night, moonlight, caves, forests, fruit, crystals, soft stars.
- **Avoid:** gore, realistic bats, horror imagery, overly childish preschool styling.
- **Priority:** character readability on a small Watch display.

### 3.2 Character Production Standard

Each launch bat should include, at minimum:

| Asset | Required | Notes |
|---|---|---|
| Idle | Yes | Primary loop animation |
| Sleep | Yes | Daytime identity |
| Wake / Drowsy | Yes | Day-to-night personality |
| Fly | Yes | Night active state |
| Pet reaction | Yes | Short touch feedback |
| Eat | Yes | Feeding interaction |
| Happy | Yes | Friendship / reward response |
| Hatch reveal | Yes | High-value emotional moment |
| Shiny palette | Yes | Same silhouette; distinct colorway |

### 3.3 Rarity Visual Rules

| Rarity | Direction |
|---|---|
| Common | Earthy, simple, warm, immediately lovable |
| Uncommon | More decorative palettes and thematic props |
| Rare | Stronger silhouette, magical motifs, more elaborate particles |
| Legendary | Distinctive palette, premium animation, strong "reveal" moment |

### 3.4 Watch UI Art Rules

- The bat or egg must visually dominate the screen.
- Progress numbers stay secondary.
- Avoid dense dashboard layouts.
- Key art must remain readable at actual Watch size.
- Animations should be short, expressive, and battery-conscious.

### 3.5 Egg Animation States

| Progress | Visual State |
|---|---|
| 0–25% | Calm / still |
| 25–50% | Occasional small shake |
| 50–75% | Visible cracks |
| 75–99% | Frequent movement / stronger crack state |
| 100% | Hatch-ready state + haptic + tap-to-reveal |

### 3.6 Pixel Artist Deliverables

- Transparent PNG sprite sheets.
- Consistent logical canvas size for all bats.
- Frame-aligned animation sheets with deterministic naming.
- Normal and Shiny palettes documented per species.
- Export previews at actual Apple Watch scale for visual QA.
- Source files preserved in layered/editable format used by the artist.

---

## 4. Build — Technical Implementation

### 4.1 Stack

| Layer | Choice | Purpose |
|---|---|---|
| Watch UI | SwiftUI | Native Watch experience |
| iPhone UI | SwiftUI | Shared Apple-native stack |
| Activity data | HealthKit | Read Step Count required for progress |
| Local persistence | SwiftData | Collection, egg state, names, Friendship, preferences |
| Backup / restore | iCloud / CloudKit | Prevent collection loss across device changes |
| Complication | WidgetKit | Persistent Watch-face presence |
| Phone sync | WatchConnectivity | Best-effort paired-device synchronization |
| Backend | None for MVP | Keep core loop local-first and low-cost |
| AI | None | Explicit product decision |

### 4.2 Architecture

```
APPLE WATCH
    │
    ▼
HealthKit Step Count
    │
    ▼
Local Game Engine
 ┌──────┬───────┬────────┐
 │Hatch │ Care  │ Time   │
 │Logic │ Logic │ State  │
 └──────┴───────┴────────┘
    │
    ▼
SwiftData
 ┌───────────────┬────────────────┐
 ▼               ▼
Watch App      WidgetKit
    │
    │ optional paired sync
    ▼
WatchConnectivity
    │
    ▼
iPhone Companion
    │
    ▼
CloudKit backup / restore
```

### 4.3 Game State

Minimum states: `egg`, `hatchReady`, `sleeping`, `drowsy`, `awake`, `happy`, `eating`, `playing`.

### 4.4 Hatch Logic

**Inputs:** egg type, required steps, current credited steps, local time state, existing collection, RNG seed.
**Outputs:** species ID, rarity, Normal/Shiny flag, hatch timestamp, credited steps.

| Example rarity | Initial target probability |
|---|---|
| Common | 65% |
| Uncommon | 25% |
| Rare | 8% |
| Legendary | 1.5% |
| Shiny modifier | 0.5% initial target |

Exact rates are tuning values for beta and may change without changing the core design.

### 4.5 Data & Privacy

- Read only the Health data required for the mechanic: Step Count.
- Do not upload raw step history to a custom server in MVP.
- Store game-derived state locally and in CloudKit backup.
- Analytics should record game events — not detailed Health history.

### 4.6 Analytics Events

Recommended minimum events: `onboarding_complete`, `step_permission_result`, `first_hatch`, `egg_complete`, `bat_collected`, `duplicate_friendship`, `companion_changed`, `feed_bat`, `purchase_unlock`, `restore_purchase`.

### 4.7 Performance & Battery Requirements

- No continuous GPS.
- No permanent Workout Session for the game loop.
- No second-by-second background step polling.
- Foreground actions should feel immediate.
- Open-to-visible-bat target: under ~1 second on supported devices.
- Hatch animation target: 2–4 seconds.

### 4.8 Platform Support

Target the current and previous major watchOS generation at development start, subject to real-device animation and performance testing. Do not sacrifice the core visual experience solely to support much older Watch hardware.

### 4.9 Critical Test Cases

- [ ] 0 → threshold hatch progression
- [ ] Large step jump between app launches
- [ ] Midnight rollover
- [ ] Time-zone and DST changes
- [ ] Watch restart / force quit
- [ ] Health permission denied or later revoked
- [ ] Phone unavailable
- [ ] Cloud restore to a new device
- [ ] Duplicate bat correctly adds Friendship
- [ ] Normal/Shiny collection flags remain correct
- [ ] Purchase and Restore Purchase survive reinstall

See [TEST_PLAN.md](TEST_PLAN.md) for which of these are covered by unit tests and which need a real device.

---

## 5. Launch — Deploy & Operate

### 5.1 Launch Plan

| Phase | Audience | Goal | Exit Criteria |
|---|---|---|---|
| Alpha | 10–20 testers | Prove the loop feels delightful | ≥80% first-hatch completion; no critical save bugs |
| Closed Beta | 50–100 Apple Watch users | Validate retention and walking motivation | D7 ~25–30%+; Health permission ≥70%; stable battery feedback |
| GA | Global App Store, English-only | Test scalable retention and paid conversion | Crash-free >99.5%; core KPIs stable |

### 5.2 North Star

| Target | Metric |
|---|---|
| **≥4** | Active Bat Days / WAU / week — a day counts when the user has real progress *and* interacts with the bat |
| **≥70%** | First hatch within 24h |
| **≥30%** | D7 retention target |

### 5.3 Supporting Metrics

| Metric | Target |
|---|---|
| Step permission completion | ≥75% |
| D1 retention | ≥50% |
| Watch opens per active day | ≥3 |
| Bats collected in first week | ≥3 |
| Complication adoption | ≥20% |
| Crash-free sessions | >99.5% |

### 5.4 Key Risks

| Risk | Mitigation |
|---|---|
| Novelty wears off | Collection depth, rarity, Friendship, Shiny variants, seasonal content, and later evolution. |
| Watch gameplay feels shallow | Keep Watch interaction short and emotionally rich; use iPhone for deeper viewing instead of stuffing menus onto Watch. |
| Battery complaints | Avoid continuous sensors, GPS, excessive background refresh, and long animations. |
| Permission refusal | Explain the benefit clearly: "Your steps hatch your bat." Provide a graceful non-progress state if permission is denied. |

---

## 6. Launch Content — 20 Bat Roster

| # | Bat | Rarity | Personality / Visual Hook | Primary Egg |
|---|---|---|---|---|
| 1 | Mochi Bat | Common | Round, sleepy, friendly starter mascot | Starter / Tiny |
| 2 | Cocoa Bat | Common | Chocolate brown, calm, wraps in wings | Tiny |
| 3 | Long Ear Bat | Common | Oversized ears, curious reactions | Forest |
| 4 | Fruit Bat | Common | Round face, food-loving | Forest |
| 5 | Cave Bat | Common | Shy, hides in wings | Tiny / Forest |
| 6 | Sleepy Bat | Common | Half-closed eyes, tiny sleep cap | Tiny |
| 7 | Dust Bat | Common | Fluffy gray, clumsy flight | Forest |
| 8 | Pebble Bat | Common | Stone-like round sleeper | Tiny |
| 9 | Strawberry Bat | Uncommon | Pink/red, strawberry motif, cheerful | Forest |
| 10 | Blossom Bat | Uncommon | Soft pink, petal particles | Forest |
| 11 | Moss Bat | Uncommon | Green/brown, tiny sprout | Forest |
| 12 | Sunset Bat | Uncommon | Orange/purple, energetic at dusk | Forest / Moon |
| 13 | Snow Bat | Uncommon | White/blue, snowflake particles | Crystal |
| 14 | Cloud Bat | Uncommon | Fluffy white-gray, dreamy | Crystal |
| 15 | Moonwing | Rare | Deep blue, moon motifs, mysterious | Moon |
| 16 | Golden Bat | Rare | Gold accents, confident sparkle | Crystal |
| 17 | Crystal Bat | Rare | Blue/purple crystalline wings | Crystal |
| 18 | Vampire Bat | Rare | Cute black/red cape, dramatic not scary | Moon |
| 19 | Galaxy Bat | Legendary | Starfield body, premium particles | Moon / Crystal |
| 20 | Eclipse Bat | Legendary | Black/gold halo, silent and rare | Special / Moon |

### 6.1 Free Tier Species

Recommended free roster: **Mochi Bat, Cocoa Bat, Long Ear Bat.** Free egg types: **Starter Egg and Tiny Egg.**

### 6.2 Current Companion Naming

Species identity remains fixed, but the player can give the owned companion a personal name. Example: Species = Moonwing, Player Name = Luna. The Watch home shows the personal name.

---

## 7. MVP Scope Lock

### 7.1 Must Have

- [ ] Apple Watch main game
- [ ] HealthKit Step Count progression
- [ ] Egg progress states and hatch animation
- [ ] 20 launch bats
- [ ] Normal + Shiny collection state
- [ ] Duplicate → Friendship EXP
- [ ] Current companion selection
- [ ] Custom naming
- [ ] Feed / Pet / Wake interactions
- [ ] Day / Dusk / Night behavior
- [ ] Watch complication
- [ ] SwiftData local save
- [ ] CloudKit backup / restore
- [ ] iPhone Batpedia / Collection / Basic History
- [ ] $1.99 one-time full unlock + Restore Purchase
- [ ] English-only launch copy

### 7.2 Explicitly Deferred

Habitat economy, evolution, moon-phase events, weather events, social, trading, challenges, breeding, GPS exploration, AR, battle systems, subscriptions, AI, real ambient-light detection.

---

## 8. MVP Definition of Done

A user can leave the iPhone behind, walk with Apple Watch, reach an egg threshold, return to the Watch, hatch a bat, save it into the Collection, interact with it, and begin another egg — **without needing the phone.**

### Emotional Definition of Done

The product is not done merely because the mechanic works. At least these moments must feel delightful on real hardware:

1. First egg appears.
2. Egg moves for the first time.
3. Egg cracks.
4. Watch gives the hatch-ready haptic.
5. Rare/Legendary reveal feels special.
6. A duplicate feels useful because Friendship increases.
7. The player sees the bat sleeping in the morning.
8. The same bat wakes and becomes active at dusk/night.

> **Core validation question:** Does this loop make users want to walk a little more and check their wrist because they care about what happens to the bat? If yes, Batwalk has product-market potential. If no, adding more systems will not fix the core experience.

---

*Batwalk PRD v1.0 — consolidated from approved product decisions and the approved visual concept board. Working title and tuning values may evolve during testing; the core Watch-first, non-AI, cozy collectible-pet direction is locked for MVP.*
