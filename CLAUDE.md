# CLAUDE.md — working on Batwalk

Batwalk is an Apple Watch-first cozy pet game. Source of truth for product
decisions: `docs/PRD.md`. Unresolved product questions: `docs/OPEN_QUESTIONS.md`.

## Rules for changes

- **Game rules go in `Packages/BatwalkCore` only**, with a unit test. Apps call
  `GameStore.mutate { ... }` and never re-implement a rule in a view.
- **Balance numbers go in `Tuning.swift`.** Don't hard-code them elsewhere.
- **Only the Watch writes the save.** The iPhone `GameStore` (role `.phone`) is read-only.
- **Never change a species `id` or `EggType` raw value** after shipping — they are save keys and asset names.
- Respect the PRD guardrails: no punishment, no pay-to-skip, Step Count only, no AI, no backend.
- Battery: no GPS, no workout sessions, no polling faster than HealthKit's hourly background delivery.

## Commands

```bash
swift test --package-path Packages/BatwalkCore   # rules + tests (works on Linux too)
xcodegen generate                                # regenerate Batwalk.xcodeproj after editing project.yml
```

CI (`.github/workflows/ci.yml`) runs the tests and unsigned simulator builds of both apps on macOS.

## When you resolve an open question

Update the code + test, then move the row in `docs/OPEN_QUESTIONS.md` to "Decided" with the date.
