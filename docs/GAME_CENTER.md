# Walking together — hatch counts only

Decision, 2026-10-23: the player chose **no step upload to Game Center**. There is
no `steps.week` board, step payload, or Watch GameKit integration. Health metrics
remain local except when the player actively shares a card. This feature cannot
change eggs, steps, species, odds, Friendship or rewards.

## Two independent choices

iPhone Settings → Walking together offers monthly and all-time hatch counts,
both off by default. The first explicit switch authenticates with Game Center;
normal launches do not authenticate when both switches are off. The explanation
identifies Apple, the Game Center profile link and possible public visibility.

Consent is bound to the local Game Center account. Sign-out/account change
disables both switches and clears in-memory friends and pending work. Disabling
a switch invalidates in-flight UI work and prevents further submissions. A score
already accepted by Apple cannot be recalled by this client; the UI explains this.
Submissions are serialized and consent is checked again after waiting. An older
in-flight request therefore cannot finish after and replace a newer monthly
score. A month change clears old rows even when the next refresh is offline.

The app requests friends access in context, provides
`NSGKFriendListUsageDescription`, respects denied/restricted access and clears
cached friends when access is revoked. Only mutually authorized friends from
Apple's friends API are displayed. Avatars remain in memory.

## App Store Connect configuration

Enable Game Center for `com.aimanjack.batwalk` only. No Watch entitlement is needed.

| ID | Type | Submission | Display | Sort / range |
|---|---|---|---|---|
| `bats.month` | Classic | Most Recent Score | Bats this month; integer; bat / bats | High to low; 0–100,000,000 |
| `bats.total` | Classic | Best Score | Bats hatched; integer; bat / bats | High to low; 0–100,000,000 |

`bats.month` stores the UTC calendar month as an integer context (`202610`) and
the number of egg hatches as its score. This supports February and 31-day months:
Apple's recurring boards use fixed intervals and have a 30-day maximum. The app
labels the social month as UTC; personal monthly challenges use local dates.
There is no automatic server-side calendar-month reset or monthly archive.

Load `.friendsOnly` with `.allTime`, paginate all ranks in batches of 100, then
filter month contexts and sort the rows locally. A stale month becomes “No update
this month”, not zero. The player is highlighted without displaying a rank. Game
Center can still expose leaderboard scores outside Batwalk; a query filter is
not a privacy access-control list.

Totals use `GameState.lifetimeHatchCount`, retained through collection-backup
history trimming. UTC monthly counts are also persisted independently of history.
Both are gameplay counters retained by redacted mirrors and trimmed backups.
Only `.egg` records count; legacy Moon Dust calls do not.
Old saves infer a lower bound from retained egg records; already discarded old
history cannot be reconstructed. New `hatchOrdinal` values let certificates keep
their place after trimming. No friend information is written into the game save.

## Provisioning and release

Base builds leave `BATWALK_GAME_CENTER_ENABLED=NO`. After the two boards exist,
run `scripts/configure-capabilities.py --game-center` (with other enabled flags)
and regenerate the project. GitHub TestFlight uses repository variable
`BATWALK_GAME_CENTER_ENABLED=true`. Capability-enabled unsigned CI validates the
overlay; it does not prove signing or Apple account behavior. The phone privacy
manifest separately declares optional gameplay content and user ID for app
functionality, linked, not tracking. The Watch manifest remains unchanged.
The GitHub upload workflow verifies all three archived bundles, matching build
numbers, no-tracking manifests, Watch Health entitlements, and phone-only Game
Center before export. Only a small sanitized verification report is uploaded;
raw entitlement files stay private to the runner and are removed afterward.

App Privacy answers are app-wide, not conditional per player. Our conservative
disclosure is Gameplay Content and User ID, linked for App Functionality, no
tracking; Health/Fitness is not uploaded by this feature. Players who leave both
switches off send no Game Center scores. Apple says developers need not declare
data Apple independently collects, but that is not a blanket exemption for the
gameplay data this app deliberately sends and retrieves. These 1.1 answers are
prepared in the release notes, not saved as an ASC draft. The authenticated ASC
form says published answers must describe the current App Store version; its
final action publishes immediately. Live 1.0 has no Game Center sharing, so the
existing Data Not Collected label remains. Publish the prepared 1.1 answers in
coordination with the 1.1 App Store release. This pass is TestFlight only.

For beta testing, do not create a release or submit the components for review.
Apple's [API demonstration](https://developer.apple.com/videos/play/tech-talks/111377/)
tests leaderboards with TestFlight before creating a release; the
[WWDC25 lifecycle](https://developer.apple.com/videos/play/wwdc2025/214/?time=1604)
likewise tests Not Live resources before App Review. The v2 API has no direct
leaderboard-to-app-version relationship; review submission items associate the
components for later publication. Actual score lookup/posting still needs a
signed TestFlight device check.

Read-only ASC verification on 2026-10-23 confirmed the 1.1 draft version
`034fe867-83fd-435a-9cda-367fe4aa0bad` has enabled Game Center app-version
`19476066-5553-45c2-af3e-4d6ad3460b0d`. Both leaderboards are unarchived and
their version 1 metadata remains Prepare for Submission. No leaderboard
review submission was created by this feature.

## Validation

Core tests cover UTC/31-day/leap-month boundaries, old month rejection, source
filtering, no future hatches, counter migration and trimmed backups. Fake-backend
tests cover no work while off, per-board consent, duplicate suppression,
pagination before month filtering, revoked friends access, sign-out/account
switches and opt-out while a request is in flight. `phone-friends` uses invented
profiles and never authenticates or submits to Apple.

Device / Game Center tests still required before declaring live social ready:

- Two test accounts with mutual friends access; verify avatar, own-row highlight
  and denied/restricted access. Prerelease scores use the same Game Center service.
- Confirm Most Recent accepts a lower monthly score (old month 8 → new month 0)
  with the new context; stale entries are hidden as unknown.
- Sign out/change account, disable either switch during a slow request, reopen
  offline, revoke friends access, and confirm no unintended submissions.
- Confirm signed entitlement and both ASC IDs/localizations, including zero scores.

## Official references

- [Leaderboard configuration and score submission type](https://developer.apple.com/help/app-store-connect/reference/game-center/leaderboards/)
- [Recurring board interval limit](https://developer.apple.com/help/app-store-connect/configure-game-center/manage-leaderboards/)
- [Score context](https://developer.apple.com/documentation/gamekit/gkleaderboard/submitscore(_:context:player:completionhandler:))
- [Friends access and consent](https://developer.apple.com/documentation/gamekit/connecting-players-with-their-friends-in-your-game)
- [Game Center visibility and privacy](https://www.apple.com/legal/privacy/data/en/game-center/)
- [App Privacy disclosure rules](https://developer.apple.com/app-store/app-privacy-details/)
- [HealthKit privacy](https://developer.apple.com/documentation/healthkit/protecting-user-privacy)
- [Testing uses the live Game Center environment](https://developer.apple.com/help/app-store-connect/configure-game-center/overview-of-testing-game-center)
