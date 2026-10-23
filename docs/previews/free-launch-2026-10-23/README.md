# Free launch · 2026-10-23

All five eggs and the 20 launch bats are free. Pools stay themed and wave 2 stays disabled. The quiet Watch companion scene and original Gentle pixel artwork are unchanged. The approved inset egg page and iPhone redesign are retained.

## Review scenarios

- Watch `egg-picker`: every egg can be selected, without an unlock message.
- iPhone `phone-settings`: help, privacy and connection; no purchase entry.
- iPhone `phone-batpedia` / `phone-batpedia-rare`: missing bats remain discovery silhouettes, with no paid lock action or completed-free-tier card.
- Existing home, egg progress, hatch, care, handoff, empty and accessibility scenarios are captured on both devices.

## Verification and provenance

The Screenshots workflow must run with `launch_roster=true`, both devices enabled, artifact output only. Screenshots are original simulator outputs and do not establish real-device HealthKit, energy or touch validation.

Core tests cover equal pools and Shiny outcomes without entitlement, every egg selectable, no trial gating, unchanged pity, legacy sealed/unsealed outcome migration and save compatibility. Hosted tests verify disabled purchase operations make zero backend calls.

CI and screenshot run links, source commit and selected artifact hashes are recorded here after they finish. No App Store submission is part of this PR.
