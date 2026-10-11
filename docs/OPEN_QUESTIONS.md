# Open Questions

Places where the PRD is silent or contradicts itself. Each one has a **current
behaviour** already implemented in `BatwalkCore`, so the game is playable today;
changing a decision usually means editing one value in `Tuning.swift` or `EggType.swift`
and its test.

| # | Question | Current behaviour in code | Where |
|---|---|---|---|
| **Q3** | What happens to steps walked while an egg is ready, or while no egg is chosen? | They are **banked** and applied to the next egg, capped at 6,000 so a multi-day backlog can't chain-hatch several eggs at once. | `Tuning.maxBankedSteps` |
| **Q4** | Friendship EXP numbers. | Level thresholds 0 / 100 / 250 / 500 / 1,000. Duplicate: Common 40, Uncommon 60, Rare 100, Legendary 200. Feed +10. Pet +2, first 10 pets per bat per day. Past Lv.5 a duplicate also pays 1 Moon Dust (Q14). | `Tuning` |
| **Q5** | How often does walking yield fruit? | 1 fruit per 1,500 credited steps; inventory caps at 9 (cap is silent — never a penalty). | `Tuning.stepsPerFruit`, `maxFruit` |
| **Q6** | Rarity odds per egg. | The PRD's global weights (65 / 25 / 8 / 1.5) are renormalised over the rarities present in each egg's pool. So Tiny is always Common; Forest ≈ 72% Common / 28% Uncommon; Moon ≈ 72% Uncommon / 23% Rare / 4% Legendary; Crystal ≈ 72% Uncommon / 23% Rare / 4% Legendary. Within a rarity, species are equally likely — except that after 10 paid hatches without a new species, the next egg is sealed to one the player hasn't met (new-species pity, Q14). | `HatchEngine`, `GameState.freezeEgg` |
| **Q7** | Is Eclipse Bat ("Special / Moon") obtainable from a special egg? | Not yet — it's in the Moon pool with Galaxy. A special event egg is a post-MVP idea. | `EggType.pool` |
| **Q10** | Can a free player see Shiny bats? | Not from free eggs. The one trial Forest Egg (Q13) uses the paid pool and so *can* hatch Shiny — a taste of the full collection. | `HatchEngine.roll`, `GameState.freezeEgg` |
| **Q11** | Wake interaction during the day. | The three pilots play Pet (~1.65 s) or Eat (~2 s), then return to the time-of-day mood; other bats retain the ~2.5 s reaction. No penalty either way. | `HomeView`, `FriendshipPage` |

When a question is answered, update the code + tests, then move the row into the
"Decided" section below with the date.

## Decided

| # | Date | Decision |
|---|---|---|
| Q2 | 2026-10-09 | After the player taps Start next egg on the reveal, free players start Tiny immediately (unless the trial egg is available, Q13). Unlocked players choose an egg and see its actual species pool. Dismissing the reveal without that action leaves the choice available on Home. Starter remains onboarding-only. |
| Q9 | 2026-10-10 | Lv.2–5 permanently display a Heart charm, Forest charm, Star charm, and Best friend crown. In addition, `ActionCatalog` defines a species-specific Lv.2 idle quirk, Lv.3 reaction and Lv.4 signature, plus Legendary Lv.1 hatch/Lv.5 secret actions. Five universal actions are available at Lv.1. Rewards share the existing EXP thresholds. Playback is added as each character's animation art is produced; see `docs/BAT_ACTIONS.md`. |
| Q1 | 2026-10-10 | Long Ear Bat stays free and joins the **Tiny Egg** pool for everyone (Primary Egg "Tiny / Forest"), so the free roster's third bat has a free egg to come from. Free players' Tiny Egg yields exactly Mochi, Cocoa, Long Ear. `EggType.designedPool`, `RosterTests.testLongEarHatchesFromTinyAndForest`. |
| Q8 | 2026-10-10 | "Bat Awake" ships as one **opt-in** local notification at dusk (18:00 local, `Tuning.duskStartHour`), a repeating calendar trigger so it fires at most once a day and costs no background work. Off by default; toggle in Watch Settings. `HatchNotifier.scheduleDuskReminder`. |
| Q12 | 2026-10-10 | The 12 Oddball Bats ship as the **first content update (v1.1)**, not at launch. They stay in `Roster.catalog` (stable IDs, numbers, assets) but are gated by `Roster.enabledWave` / `BATWALK_CONTENT_WAVE`; egg pools only include enabled waves. Launch animation work stays on the 20-bat roster and the update gives the App Store a second moment. Screenshot demos show wave 2. |
| Q13 | 2026-10-10 | **Free trial egg.** Once a free player has met all three free bats, one Forest Egg (`Tuning.freeTrialEgg`) appears in the picker. It uses the paid Forest pool (Shiny possible), costs the full 4,000 steps, and is offered exactly once. Never a step skip — a taste of what the unlock holds, shown at the moment the free tier runs out. |
| Q14 | 2026-10-10 | **Collection pacing.** Shiny chance 0.5% → 3%, with a guaranteed Shiny every 40 paid hatches and ×3 odds for a species at Lv.5. After 10 paid hatches with no new species, the next egg seals an unmet species from its pool. Duplicates of a Lv.5 bat pay **Moon Dust**; 4 dust calls a bat the player hasn't met (within their tier — dust never buys paid content). All numbers in `Tuning`; rules in `GameState.freezeEgg`, `hatch`, `callNewBat`; tests in `EconomyTests`. |
