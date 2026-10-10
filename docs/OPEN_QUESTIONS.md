# Open Questions

Places where the PRD is silent or contradicts itself. Each one has a **current
behaviour** already implemented in `BatwalkCore`, so the game is playable today;
changing a decision usually means editing one value in `Tuning.swift` or `EggType.swift`
and its test.

| # | Question | Current behaviour in code | Where |
|---|---|---|---|
| **Q1** | **Long Ear Bat is a free species (§6.1), but its primary egg is Forest — a paid egg.** How does a free player get it? | Free players' Tiny Egg yields exactly the three free species: Mochi, Cocoa, Long Ear. Paid players' Tiny Egg uses the roster pool (Mochi, Cocoa, Cave, Sleepy, Pebble). Alternative: swap Long Ear for a Tiny-egg common (e.g. Sleepy) in the free roster. | `EggType.freePool` |
| **Q3** | What happens to steps walked while an egg is ready, or while no egg is chosen? | They are **banked** and applied to the next egg, capped at 6,000 so a multi-day backlog can't chain-hatch several eggs at once. | `Tuning.maxBankedSteps` |
| **Q4** | Friendship EXP numbers. | Level thresholds 0 / 100 / 250 / 500 / 1,000. Duplicate: Common 40, Uncommon 60, Rare 100, Legendary 200. Feed +10. Pet +2, first 10 pets per bat per day. | `Tuning` |
| **Q5** | How often does walking yield fruit? | 1 fruit per 1,500 credited steps; inventory caps at 9 (cap is silent — never a penalty). | `Tuning.stepsPerFruit`, `maxFruit` |
| **Q6** | Rarity odds per egg. | The PRD's global weights (65 / 25 / 8 / 1.5) are renormalised over the rarities present in each egg's pool. So Tiny is always Common; Forest ≈ 72% Common / 28% Uncommon; Moon ≈ 72% Uncommon / 23% Rare / 4% Legendary; Crystal ≈ 72% Uncommon / 23% Rare / 4% Legendary. Within a rarity, species are equally likely. | `HatchEngine` |
| **Q7** | Is Eclipse Bat ("Special / Moon") obtainable from a special egg? | Not yet — it's in the Moon pool with Galaxy. A special event egg is a post-MVP idea. | `EggType.pool` |
| **Q8** | "Bat Awake" notification — when, and opt-in? | Not implemented. Only "Ready to hatch" is posted (from hourly background step sync). Proposal: one optional dusk notification. | `HatchNotifier` |
| **Q10** | Can a free player see Shiny bats? | No — Shiny requires the full unlock (§2.10). A free player's hatches are never Shiny. | `HatchEngine.roll` |
| **Q11** | Wake interaction during the day. | "Wake" plays the awake animation for ~2 s, then the bat goes back to its time-of-day mood. No penalty either way. | `CareView` |

When a question is answered, update the code + tests, then move the row into the
"Decided" section below with the date.

## Decided

| # | Date | Decision |
|---|---|---|
| Q2 | 2026-10-09 | After the player taps Start next egg on the reveal, free players start Tiny immediately. Unlocked players choose an egg and see its actual species pool. Dismissing the reveal without that action leaves the choice available on Home. Starter remains onboarding-only. |
| Q9 | 2026-10-09 | Lv.2–5 permanently display a Heart charm, Forest charm, Star charm, and Best friend crown. The next keepsake is visible on Friendship. Rewards use the existing EXP thresholds and require neither a purchase nor a rare hatch; custom species animation art can follow later. |
