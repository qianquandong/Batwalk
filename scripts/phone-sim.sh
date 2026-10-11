#!/usr/bin/env bash
# Create and boot an iPhone simulator; share PHONE_SIM with the CI's next steps.
set -euo pipefail
runtime=$(xcrun simctl list runtimes -j | python3 -c '
import json, sys
rs = [r for r in json.load(sys.stdin)["runtimes"] if r.get("platform") == "iOS" and r.get("isAvailable")]
print(rs[-1]["identifier"] if rs else "")')
[ -n "$runtime" ] || { echo "::error::No iOS simulator runtime"; exit 1; }
devtype=$(xcrun simctl list devicetypes -j | python3 -c '
import json, sys
ds = [d for d in json.load(sys.stdin)["devicetypes"] if d["name"].startswith("iPhone")]
pref = [d for d in ds if d["name"].endswith("Pro") and "Max" not in d["name"]]
print((pref or ds)[-1]["identifier"])')
udid=$(xcrun simctl create "Batwalk iPhone" "$devtype" "$runtime")
xcrun simctl boot "$udid"
xcrun simctl bootstatus "$udid" -b >/dev/null 2>&1 || sleep 20
echo "::notice::iPhone simulator: $devtype on $runtime"
env_file="${CM_ENV:-${GITHUB_ENV:-${BATWALK_ENV_FILE:-}}}"
if [ -n "$env_file" ]; then
  printf 'PHONE_SIM=%s\n' "$udid" >> "$env_file"
else
  printf 'PHONE_SIM=%s\n' "$udid"
fi
