# Watch onboarding and UI handoff

This change implements the first Watch phase of the Belly-inspired Batwalk design research prepared on 2026-10-24. It retains Batwalk's own artwork, palette and game rules. The scope is onboarding, companion interaction, egg progress and Watch help; the iPhone navigation is unchanged.

## Player flow

1. A new player sees the starter egg and **Meet them**. This introduction is remembered even before a game save exists.
2. **Enable Steps** explains that walking hatches the egg. The existing step setup still requires real positive step data before starting. Zero readings remain ambiguous; they are never described as proof that access was denied.
3. The first egg offers **View progress** and a brief invitation to return later. Visiting the egg page completes that navigation hint.
4. At the first hatch, an optional instruction explains tapping the egg or turning the Crown. The **Hatch** button remains available. The saved result appears as **Meet Mochi**, followed by **Say hello**.
5. The companion page teaches a real tap, then feeding only when fruit exists. Each interaction tip can be skipped. Zero fruit bypasses the feeding lesson; tapping the empty Feed control explains that fruit comes from walking.
6. **Choose an egg** follows the first interaction. **Later** closes the guide while leaving egg selection available from the egg page. Subsequent hatches retain the faster next-egg flow.

The first hatch no longer automatically opens the egg picker or requests notification permission. Alerts are explicitly enabled from **More → Options**. **How to play → Show tips again** replays relevant companion/egg tips without restarting first launch, reopening permissions or replacing an active egg.

## Layout changes

- The companion remains the main visual subject. Normal visits keep Feed as the persistent control; teaching text and brief result messages appear only when relevant.
- The egg page leads with remaining steps, then shows credited/target progress in secondary text. It uses a static egg, a fine progress line and a compact More control. Ready, missing-egg and step-query states expose their next action.
- First-launch, step-setup, hatch and progress layouts keep actions reachable while large text scrolls. A short hatch glow replaces indefinite pulsing. Reduced Motion retains direct controls and readable outcomes.
- Step setup retries after zero or failed readings only query data. Initial setup and a failed authorization flow may request access again. Returning from Settings also queries without opening another permission prompt.

## State and compatibility

`Apps/Shared/WatchOnboarding.swift` stores versioned teaching progress in device-local UserDefaults, separately from `GameState`. It binds to the real save identity once a game starts. Existing saves without a tutorial record and restored collections skip forced onboarding; help remains available.

Gameplay actions are committed before their tutorial callbacks. Reconciliation recovers a saved first hatch, a depleted-fruit feeding step and a newly selected egg after interruption. It never hatches again or grants a reward. Completed and skipped tips persist. Demo guides use memory-only state.

No egg targets, hatch odds, step accounting, fruit rewards, friendship rules or gameplay save schema change. Existing eggs keep their saved targets. Free content and the absence of hunger/death/streak penalties remain intact.

## Review entry points

| Area | Files |
| --- | --- |
| Tutorial state and migration | `Apps/Shared/WatchOnboarding.swift`, `Apps/Tests/WatchOnboardingTests.swift` |
| First launch and page navigation | `Apps/Watch/RootView.swift` |
| Interaction lessons and next egg | `Apps/Watch/HomeView.swift`, `Apps/Watch/WatchComponents.swift` |
| Hatch instruction and first reveal | `Apps/Watch/HatchViews.swift` |
| Egg progress and recovery controls | `Apps/Watch/ProgressPage.swift`, `Apps/Watch/StepSetupView.swift` |
| Replay and explicit alert access | `Apps/Watch/SettingsView.swift`, `Apps/Watch/HowToPlayView.swift` |
| Screenshot fixtures | `Apps/Shared/DemoMode.swift` |

## Validation checklist

Mac compilation, hosted application tests and small/large Watch screenshot review are **pending at this handoff**. The checks below are acceptance requirements, not recorded passes.

- Run the existing CI workflow: core rules, Watch/iPhone simulator builds, hosted application tests and capability-enabled build. The new tutorial tests cover persistence, migration, restore, interrupted actions, zero fruit, skipped tips and preview isolation.
- Run Watch screenshots with `watch_size: small` and `watch_size: large`, `watch_only: true`, `publish: false`. Review text, button reachability and stable art placement; keep the captured commit identifiable.
- New demo scenarios: `onboarding`, `onboarding-large-type`, `first-egg-large-type`, `first-hatch-ready`, `first-hatch-ready-large-type`, `first-reveal`, `first-reveal-large-type`, `tutorial-hello`, `tutorial-hello-large-type`, `tutorial-feed`, `tutorial-no-fruit`, `tutorial-next-egg`.
- Include existing `first-egg`, `home`, `home-large-type`, `progress-61`, `progress-100`, `progress-large-type`, `step-setup`, `step-no-data`, `step-read-error`, `step-no-data-large-type`, `egg-picker` and `settings` in review.
- Interactively verify skip, Later, Help replay, existing-save launch, restored collection and interruption after the first hatch. Confirm no forced feeding and no duplicate rewards.
- On a real Watch, verify step authorization/zero-data recovery, Crown navigation and hatch input, VoiceOver, Reduced Motion, Always On and haptics. Simulator screenshots do not establish those results.
