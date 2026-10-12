#!/usr/bin/env bash
# Create and boot an Apple Watch simulator; share SIM with the CI's next steps.
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

device_types=$(xcrun simctl list devicetypes -j | python3 -c '
import json, os, sys
ds = [d for d in json.load(sys.stdin)["devicetypes"] if d["name"].startswith("Apple Watch")]
small = os.environ.get("BATWALK_WATCH_SIZE") == "small"
sizes = ["41mm", "40mm", "42mm"] if small else ["46mm", "45mm"]
for size in sizes:
    for d in reversed(ds):
        if size in d["name"]:
            print(d["identifier"])')

# Xcode lists obsolete device types too. Only a successful create confirms that
# this installed runtime supports a model; try the preferred sizes in order.
udid=""
while IFS= read -r devtype; do
  [ -n "$devtype" ] || continue
  if udid=$(xcrun simctl create "Batwalk Watch" "$devtype" "$runtime" 2>/dev/null); then
    break
  fi
done <<< "$device_types"
[ -n "$udid" ] || { echo "::error::No compatible Watch model for requested size"; exit 1; }
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || sleep 20
echo "::notice::Simulator: $devtype on $runtime"
env_file="${CM_ENV:-${GITHUB_ENV:-${BATWALK_ENV_FILE:-}}}"
if [ -n "$env_file" ]; then
  printf 'SIM=%s\n' "$udid" >> "$env_file"
else
  printf 'SIM=%s\n' "$udid"
fi
