#!/usr/bin/env bash
# Install the built Watch app on $SIM and screenshot every demo scenario into $1.
set -euo pipefail
out="$1"
bundle=com.aimanjack.batwalk.watchkitapp
app=$(find build/Build/Products -maxdepth 2 -path "*watchsimulator/*.app" | head -n 1)
[ -n "$app" ] || { echo "::error::Built Watch app not found"; exit 1; }
mkdir -p "$out"
xcrun simctl install "$SIM" "$app"
scenarios=$(grep -oE '"[a-z]+-[a-z]+"|"walk"|"care"|"collection"' Apps/Watch/DemoMode.swift | tr -d '"' | awk '!seen[$0]++')
i=0
for sc in $scenarios; do
  i=$((i + 1))
  xcrun simctl terminate "$SIM" "$bundle" >/dev/null 2>&1 || true
  xcrun simctl launch "$SIM" "$bundle" -BatwalkDemo "$sc" >/dev/null
  sleep 7
  xcrun simctl io "$SIM" screenshot "$out/$(printf '%02d' $i)-$sc.png" >/dev/null
  echo "captured $sc"
done
