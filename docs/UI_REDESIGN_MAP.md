# UI Redesign — implementation map

Source of truth: the approved boards in [`Art/ui-boards/`](../Art/ui-boards/)
(`watch-ui-spec.png`, `iphone-companion.png`, `overview.png`) and the task list
[`UI_REDESIGN_TASKS.md`](UI_REDESIGN_TASKS.md). Game rules are unchanged.

## P0 — current code → screen → change

| Current file | Screen | Change |
|---|---|---|
| `Apps/Watch/BatwalkWatchApp.swift` | watchOS entry | Wire Settings page, command channel from iPhone, haptic policy |
| `Apps/Watch/RootView.swift` | vertical pages + onboarding | Pages: Home · Progress · Friendship · Bats · Settings; onboarding restyled on night sky |
| `Apps/Watch/HomeView.swift` | Home, hatch reveal, egg picker, sky | Home → `BatHeroView` on `NightSkyBackground` + glass name/progress card; ready egg → `HatchReadyView` + `HatchSequenceView`; egg picker restyled |
| `Apps/Watch/WalkView.swift` | Walk | → **Progress**: `BatwalkProgressRing` + stat rows; Health text moved to Settings |
| `Apps/Watch/CareView.swift` | Care | → **Friendship**: bat, level, `FriendshipProgressView`, `FeedButton`, hearts + bounce |
| `Apps/Watch/BatsView.swift` | Collection + detail | 3-col `BatCollectionTile` / `LockedBatTile`, unlock reveal; detail in glass cards |
| — (new) `Apps/Watch/SettingsView.swift` | Settings | Companion, Notifications, Health Access (Connected / Needs attention), Restore Purchase, version |
| `Apps/Watch/StepService.swift` | HealthKit | + authorization request status for Settings (read-only; no polling change) |
| `Apps/Watch/DemoMode.swift` → `Apps/Shared/DemoMode.swift` | demo states | Shared by both apps; all P11 states |
| `Apps/Phone/BatwalkPhoneApp.swift` | iOS entry + tabs | Light theme; tabs Batpedia · History · Stats · Unlock |
| `Apps/Phone/BatpediaView.swift` | Batpedia + Large View | Normal/Shiny segment, `BatCard`/`LockedBatCard`; **Bat Detail** hero + info rows + Set as Companion |
| `Apps/Phone/HistoryAndUnlockViews.swift` | History + Unlock | History: 2×2 `StatCard` + Hatch Timeline; Unlock: paywall hero, benefits, CTA |
| — (new) `Apps/Phone/StatsView.swift` | Collection Stats | Progress hero, milestones 5/10/15/20, recent hatches |
| `Apps/Shared/Sprites.swift` | `BatSprite`, `EggSprite`, resolver | Float/twitch moved into `BatwalkMotion`; `EggIcon`, `FruitIcon`, silhouettes |
| `Apps/Shared/PhoneSync.swift` | WatchConnectivity | + iPhone→Watch command (`setCompanion`) so the Watch stays the only writer |
| `Apps/Shared/GameStore.swift`, `PurchaseManager.swift`, `Persistence.swift` | models / save / IAP | Unchanged behaviour |
| `Packages/BatwalkCore` | rules | Display helpers only: Friendship EXP-in-level, favourite-fruit lore |

New shared design system: `Apps/Shared/DesignSystem/` — `BatwalkTheme.swift`
(colours, gradients, spacing, radii, type, rarity), `BatwalkMotion.swift`
(float, twitch, bounce, appear, press, Reduce Motion), `BatwalkComponents.swift`
(glass card, primary button, progress ring, chips, night sky, heart burst, icons).

## Assumptions (documented, not product changes)

- **Mochi's colours.** The UI boards draw Mochi pink; the approved concept board draws Mochi brown and the pink bat as Strawberry. The existing brown Mochi art is kept (P7: never redesign the character). Swapping is an asset change only.
- **iPhone "Set as Companion".** The Watch is the only writer of the save, so the iPhone sends the request to the Watch (WatchConnectivity user-info, delivered even if the Watch app is closed) and the Watch applies it.
- **Favourite fruit** is display-only lore taken from the concept board (Mochi: Berry, Strawberry: Strawberry, Moonwing: Moon Berry, Galaxy: Star Fruit). It does not change Friendship gain. Species without lore hide the row.
- **Watch page transitions.** watchOS vertical paging is kept (custom transitions fight the Digital Crown); each page's content does the spec's fade + 12 pt slide when it appears.
- **Ear twitch.** Sprites are single images, so the twitch is a quick ±3° head tilt every 6–10 s.
- **iPhone tab bar.** The system tab bar, tinted brand purple, instead of a custom floating bar.
