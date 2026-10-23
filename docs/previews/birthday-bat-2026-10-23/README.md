# Birthday bat — 2026-10-23

The existing characters gain a tiny pixel party hat. iPhone Settings accepts month/day only and shows the Watch confirmation state. No Watch controls are added.

New simulator scenarios: Watch `birthday`; iPhone `phone-birthday`, `phone-birthday-settings`, `phone-certificate-birthday`. All use in-memory fixtures with today's date and the launch roster. The certificate retains the hatch year; the detail page lists keepsakes from different years.

Validation covers date/leap-day/timezone boundaries, hatch and no-hatch rules, old saves, trimmed backup, privacy redaction, request ordering/expiry, duplicate receipt delivery, Watch save failures, queued request restoration and card rendering. The simulator/hosted and Screenshots workflow provenance is added after those jobs complete; local core success alone does not certify the app build.
