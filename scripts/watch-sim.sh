#!/usr/bin/env bash
# Create and boot an Apple Watch simulator; exports SIM=<udid> to $GITHUB_ENV.
set -euo pipefail

pick_runtime() {
  xcrun simctl list runtimes -j | python3 -c '
import json, sys
rs = [r for r in json.load(sys.stdin)["runtimes"] if r.get("platform") == "watchOS" and r.get("isAvailable")]
print(rs[-1]["identifier"] if rs else "")'
}

runtime=$(pick_runtime)
if [ -z "$runtime" ]; then
  echo "No watchOS simulator runtime installed — downloading (several minutes)…"
  xcodebuild -downloadPlatform watchOS
  runtime=$(pick_runtime)
fi
[ -n "$runtime" ] || { echo "::error::No watchOS simulator runtime available"; exit 1; }

devtype=$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
ds = [d for d in json.load(sys.stdin)["devicetypes"] if d["name"].startswith("Apple Watch")]
pref = [d for d in ds if "46mm" in d["name"] or "45mm" in d["name"]]
print((pref or ds)[-1]["identifier"])')

udid=$(xcrun simctl create "Batwalk Watch" "$devtype" "$runtime")
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || sleep 20
echo "::notice::Simulator: $devtype on $runtime"
echo "SIM=$udid" >> "$GITHUB_ENV"
