# ADR 0002 — Store the save as one Codable blob in SwiftData

**Status:** Accepted · 2026-10-06

## Context

PRD §4.1 picks SwiftData for local persistence and CloudKit for backup.
SwiftData + CloudKit imposes rules: every attribute optional or defaulted, no
unique constraints, relationships optional. Modelling bats, eggs, history and
ledger as separate synced entities would also mean per-entity merge conflicts
between devices and partially-synced saves after a restore.

## Decision

`SaveRecord` is a single SwiftData model with `payload: Data` (the JSON-encoded
`GameState`), `updatedAt`, and `writer`. The Watch writes it; CloudKit mirrors it.

If a fresh install creates a new save before the iCloud copy arrives, the app
keeps whichever save `isRicher` (more hatches, then more lifetime steps) and
deletes the other.

## Consequences

- One atomic unit: a restore is never half a collection.
- Schema evolves in Swift (`GameState.schemaVersion`), with migrations unit-tested in the core package.
- The save is a few KB, well within CloudKit record limits.
- No SwiftData queries over individual bats — not needed; the whole state is in memory anyway.
- **Before shipping a v2 save format**, add a custom `init(from:)` that tolerates missing keys.
