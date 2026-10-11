#!/usr/bin/env bash
# A temporary, interactive simulator session. No signing or Apple account access.
set -euo pipefail
: "${SIM:?Boot the Watch simulator first}"
minutes="${BATWALK_SESSION_MINUTES:-30}"
[[ "$minutes" =~ ^[0-9]+$ ]] && [ "$minutes" -ge 1 ] && [ "$minutes" -le 40 ] || {
  echo "Session duration must be between 1 and 40 minutes." >&2
  exit 1
}
app="build/Build/Products/Debug-watchsimulator/Batwalk.app"
[ -d "$app" ] || { echo "Built Watch app is missing." >&2; exit 1; }
bundle=com.aimanjack.batwalk.watchkitapp
xcrun simctl install "$SIM" "$app"
xcrun simctl status_bar "$SIM" override --time '9:41' >/dev/null 2>&1 || true

# Desktop launchers let a tester reset a scenario without typing commands.
# All progress stays in memory; these demos do not use HealthKit, sync or StoreKit.
python3 - "$SIM" <<'PY'
from pathlib import Path
import shlex
import sys

desktop = Path.home() / "Desktop" / "Batwalk Test Scenarios"
desktop.mkdir(parents=True, exist_ok=True)
sim = shlex.quote(sys.argv[1])
bundle = "com.aimanjack.batwalk.watchkitapp"
scenarios = {
    "01 - Ready to hatch": "hatch-ready",
    "02 - Pet and feed Mochi": "fruit-available",
    "03 - Friendship level 4": "friendship-4",
    "04 - Meet Sticky": "pilot-sticky",
    "05 - Meet Walker": "pilot-walker",
    "06 - Bat collection": "collection-rare",
    "07 - First egg": "first-egg",
}
for label, scenario in scenarios.items():
    path = desktop / f"{label}.command"
    path.write_text(f"""#!/bin/bash
set -euo pipefail
xcrun simctl terminate {sim} {bundle} >/dev/null 2>&1 || true
xcrun simctl launch {sim} {bundle} -BatwalkDemo {shlex.quote(scenario)}
open -a Simulator --args -CurrentDeviceUDID {sim}
""", encoding="utf-8")
    path.chmod(0o755)
(desktop / "READ ME.txt").write_text("""Batwalk hands-on Watch test

The simulator opens with an egg ready to hatch. Click its buttons, drag to
swipe between pages, and use the simulated Digital Crown to scroll.

Double-click a numbered .command file here to restart with another scenario.
This resets demo progress. These scenarios preview all 32 bats, including the
12 planned for a later content wave; the current TestFlight build ships 20.

Demo actions work locally in memory. Real steps, paired-device synchronization,
cloud backup and real purchases are not connected in this session.

The workflow holds the simulator for 30 minutes. To finish early, cancel this
build in Codemagic. No build is signed, uploaded to Apple or submitted.
""", encoding="utf-8")
PY

xcrun simctl launch "$SIM" "$bundle" -BatwalkDemo hatch-ready
open -a Simulator --args -CurrentDeviceUDID "$SIM"
sleep 5
mkdir -p build/reports
xcrun simctl io "$SIM" screenshot build/reports/watch-simulator-ready.png
echo "READY: Batwalk is open. Connect using Codemagic's VNC details."
echo "Desktop > Batwalk Test Scenarios contains one-click scenario launchers."
echo "Session lasts $minutes minutes from now; cancel the build when finished."
caffeinate -dimsu -w "$$" &
keep_awake=$!
trap 'kill "$keep_awake" 2>/dev/null || true' EXIT
for ((remaining=minutes; remaining>0; remaining--)); do
  echo "Hands-on session: $remaining minutes remaining."
  sleep 60
done
echo "Hands-on session complete."
