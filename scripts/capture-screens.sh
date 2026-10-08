#!/usr/bin/env bash
# Install a built app on simulator $SIM and screenshot each DemoMode scenario.
#   capture-screens.sh <watch|phone> <outdir>
set -euo pipefail
platform="$1"
out="$2"
if [ "$platform" = watch ]; then
  bundle=com.aimanjack.batwalk.watchkitapp
  app=$(find build/Build/Products -maxdepth 2 -path "*watchsimulator/*.app" | head -n 1)
else
  bundle=com.aimanjack.batwalk
  app=$(find build/Build/Products -maxdepth 2 -path "*iphonesimulator/*.app" | head -n 1)
fi
[ -n "$app" ] || { echo "::error::Built $platform app not found"; exit 1; }
mkdir -p "$out"
xcrun simctl install "$SIM" "$app"
xcrun simctl status_bar "$SIM" override --time "9:41" >/dev/null 2>&1 || true
scenarios=$(grep "// scenarios:$platform" Apps/Shared/DemoMode.swift | grep -oE '"[a-z0-9-]+"' | tr -d '"')
i=0
for sc in $scenarios; do
  i=$((i + 1))
  xcrun simctl terminate "$SIM" "$bundle" >/dev/null 2>&1 || true
  xcrun simctl launch "$SIM" "$bundle" -BatwalkDemo "$sc" >/dev/null
  sleep 6
  xcrun simctl io "$SIM" screenshot "$out/$(printf '%02d' $i)-$sc.png" >/dev/null
  echo "captured $platform/$sc"
done
