# Weekly recap, monthly outfits and phone reminders

The Watch companion scene remains a bat plus Feed. Its only addition is the selected small pixel accessory; Options → Outfit handles the choice.

New scenarios: `phone-recap`, `phone-challenge`, `phone-challenge-gold`, `outfit-gold`. All use artificial local fixtures and the existing portrait art.

## Native evidence

- Source: `4b0ae529228707ca60a59e12d7f1a8902b3ac333`.
- [Screenshots run](https://github.com/qianquandong/Batwalk/actions/runs/39914860105): a small Watch `outfit-gold` capture and all 20 iPhone scenarios, with the shipping 20-bat roster. Original PNGs below are copied unchanged from its artifact; hashes are in [manifest.json](manifest.json).
- [CI run](https://github.com/qianquandong/Batwalk/actions/runs/39914857413): Linux core tests, script/art checks, both native simulator builds, 42 hosted app tests (zero failures), and the capability-enabled build passed. The PR's current check records additionally cover the subsequent privacy-transfer and stable-week-number fixes; neither changes these layouts.
- The month cards use eager rows: all dates are visible both in the preview and the exported image. Hosted export checks cover an empty weekly card and six-row months at 0/1/3/6 hatches, all at 1200 × 1200.
- The accessory was reduced after inspecting the first native capture, so the existing bat's face and body stay visible. The Watch still has a single Feed control.

| Preview | File |
|---|---|
| Weekly recap and both share actions | [weekly-recap.png](phone/weekly-recap.png) |
| Bronze month, complete calendar | [monthly-bronze.png](phone/monthly-bronze.png) |
| Gold month, complete calendar | [monthly-gold.png](phone/monthly-gold.png) |
| Companion wearing the same small accessory | [companion.png](phone/companion.png) |
| Small Watch with Gold outfit | [outfit-gold.png](watch/outfit-gold.png) |

Rules and persistence are covered by `SocialProgressTests`: local date boundaries, Shiny precedence, empty weeks, challenge thresholds, old-save/backup trimming, stable week numbering and reminder schedules. Screenshots prove rendering, not real-device notifications, haptics or battery use. Notifications remain off by default; enable and test their timing on the paired beta device.
