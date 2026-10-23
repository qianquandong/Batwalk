# Birth certificates and collection sharing · 2026-10-23

- New iPhone scenarios: `phone-certificate`, `phone-certificate-shiny`, `phone-poster`.
- Fixed 400 pt cards render with ImageRenderer scale 3 to 1200 × 1200. Existing Gentle pixel portraits remain unchanged.
- Static Shiny certificate shipped; no reveal video. The odds line says **3% base** because friendship and pity may improve it.
- Core: tolerant old receipts, local calendar days, offline approximate eight-phase MoonPhase, new egg milestones with existing targets preserved.
- Privacy: ordinary mirrors and collection backups omit step accounting and private certificate metrics. A dedicated per-certificate action requests only that receipt from Watch, held in memory; it never changes the game or queues a background transfer.
- The initial show-steps preference does not request anything. Old data stays visibly unavailable instead of inventing dates.

## Verification and screenshot provenance

126 Linux core tests passed after receipt, redaction, moon-phase and milestone changes. All app Swift sources pass a parser check. Native hosted/render tests and final simulator builds are verified separately by CI.
The Screenshots workflow must capture Watch and iPhone at the final PR commit. Downloaded original PNGs and the workflow/commit provenance are added here after that run; no simulator screenshots are claimed before it completes.

Moon estimate reference: [NASA mean synodic month](https://eclipse.gsfc.nasa.gov/phase/phases0001.html) and [NASA phase tables](https://ntrs.nasa.gov/api/citations/19950008253/downloads/19950008253.pdf). This is decorative, offline, and can differ near phase boundaries.
