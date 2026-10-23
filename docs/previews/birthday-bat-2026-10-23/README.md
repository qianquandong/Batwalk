# Birthday bat — 2026-10-23

Optional month/day settings are confirmed by the Watch. Birthday hatches retain a small, differently coloured hat for each year; without a hatch the companion wears it for that day. Original characters and the quiet Watch controls are preserved. February 29 observes February 28 in non-leap years.

## Native screenshots

- [Watch birthday](watch-birthday.png): [Screenshots 39916498656](https://github.com/qianquandong/Batwalk/actions/runs/39916498656), success, source `cb41bfe3dfecc1a7f870f422f507ccde9e5ddab6`, focused Watch scenario `birthday`.
- [iPhone companion](phone-birthday-final.png), [saved settings](phone-birthday-settings-final.png), [pending confirmation](phone-birthday-pending-final.png), [birthday certificate](phone-certificate-birthday-final.png): [Screenshots 39917804909](https://github.com/qianquandong/Batwalk/actions/runs/39917804909), success, source `fbb6a8a8f78d9fb9239988f1489389b90696fc98`, all 24 iPhone scenarios.
- Both use `launch_roster=true`. PNGs are unedited simulator captures; hashes and exact source commits are in `screenshots.json`. The source commit in that manifest is authoritative.

The hat now touches the forehead, retains the ears and face, and stays separate from the small monthly accessory. The iPhone settings clearly distinguish a saved date from a queued change. A subsequent one-line formatting fix displays celebration years as `2026`, rather than locale-grouped `2,026`; the certificate image predates that correction.

The native birthday certificate capture shows the complete card and its Share card button. The screenshot was checked against the original artifact and its SHA-256 hash; both the birthday hat and monthly accessory render together. Actual system share destinations remain a device smoke check.

## Validation

[Implementation CI 39917561334](https://github.com/qianquandong/Batwalk/actions/runs/39917561334) passed for `fbb6a8a`: Linux core, release scripts and artwork checks, Watch and iPhone simulator builds, hosted app tests, and capability-enabled unsigned validation. Local Swift 5.10/Linux: 145 tests passed, 0 failures. Eleven birthday core cases cover date/leap-day/timezone boundaries, permanent and temporary hats, old saves, backup trimming/privacy redaction, request order/expiry, and late successful confirmation. Six new hosted cases exercise Watch-only persistence, both delivery orders, queued restoration, unavailable sessions, stale requests, failure rollback, and a 1200px birthday card render.

No App Store or TestFlight action was performed by this change. Physical paired-device delivery remains a TestFlight smoke check.
