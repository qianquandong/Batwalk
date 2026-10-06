# Test Plan — PRD §4.9 Critical Test Cases

| Case | Unit test (`swift test`) | Needs real device / manual |
|---|---|---|
| 0 → threshold hatch progression | `GameStateTests.testZeroToThresholdHatchProgression` | Walk 2,000 steps, feel the haptic |
| Large step jump between app launches | `testLargeJumpFillsEggAndBanksRemainderWithCap`, `StepLedgerTests` | Leave app closed a day, reopen |
| Midnight rollover | `testMidnightRolloverCapturesYesterdaysTailThenToday`, `testDaysToSync` | Keep app open across midnight |
| Time-zone and DST changes | `testOlderDayReappearingCreditsNothing`, `testDayKeyIsZeroPaddedAndCalendarAware` | Change zone in Settings; DST weekend |
| Watch restart / force quit | `testSameSeedSameResult` (hatch can't be rerolled), `testSaveRoundTripsThroughJSON` | Force-quit while egg is ready; reboot Watch |
| Health permission denied or later revoked | Ledger never credits negative (`testTotalGoingDownCredits…`) | Deny in onboarding → Walk shows hint, no crash |
| Phone unavailable | — (Watch never depends on the phone) | Airplane-mode the iPhone, play a full loop |
| Cloud restore to a new device | `testRicherSavePrefersMoreHatches` | Erase Watch, reinstall, wait for iCloud |
| Duplicate bat correctly adds Friendship | `testDuplicateAddsFriendshipInsteadOfCopy` | — |
| Normal/Shiny collection flags remain correct | `testShinyOfOwnedSpeciesSetsShinyFlagNotDuplicate` | — |
| Purchase and Restore Purchase survive reinstall | `testPaidEggKeepsPaidPoolIfEntitlementLost` | StoreKit config in Xcode → buy, delete app, restore |

Run unit tests:

```bash
swift test --package-path Packages/BatwalkCore
```
