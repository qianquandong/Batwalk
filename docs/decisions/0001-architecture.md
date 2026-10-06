# ADR 0001 — Watch-authoritative architecture with a pure-Swift rules package

**Status:** Accepted · 2026-10-06

## Context

The PRD (§4) requires the Watch to be fully playable without the iPhone, a
local-first save with CloudKit backup, a complication, best-effort phone sync,
no backend, and a long list of edge cases (midnight, DST, time zones, restore,
force-quit) that must not lose or double-count progress.

## Decision

1. **All game rules live in `Packages/BatwalkCore`** — a Swift package with no
   UI, HealthKit, or SwiftData imports. `GameState` is a value type; every rule
   is a pure mutation, covered by `swift test`.
2. **The Watch is the only writer of the save.** The iPhone is a read-only
   mirror (CloudKit copy + WatchConnectivity application context). Two writers
   would need conflict resolution; one writer doesn't.
3. **Purchases are read from StoreKit on each device**, not synced. A purchase
   on the iPhone unlocks the Watch via `Transaction.currentEntitlements`.
4. **Steps are credited through a ledger of HealthKit daily totals**
   (`StepLedger`), never by summing samples. Credit = increase in today's
   cumulative total since last seen. This is idempotent, so re-reading is
   always safe.
5. **Hatch outcomes are seeded at egg creation.** Force-quitting before the
   reveal yields the same bat.
6. **The complication reads a tiny App Group snapshot** written by the app,
   not the database.

## Consequences

- Rule changes are fast to test and impossible to "fix in the UI".
- The iPhone can't play or edit — consistent with PRD §2.5.
- If a Watch is lost *before* CloudKit syncs, the last few minutes may be lost. Acceptable for MVP.
- HealthKit hides read-permission denial; a denied user sees 0 steps and a
  hint on the Walk screen rather than an error.
