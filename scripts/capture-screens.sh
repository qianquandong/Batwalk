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
if [ -n "${BATWALK_SCREEN_SCENARIO:-}" ]; then
  printf '%s\n' "$scenarios" | grep -Fxq "$BATWALK_SCREEN_SCENARIO" || { echo "::error::Unknown screenshot scenario"; exit 1; }
  scenarios="$BATWALK_SCREEN_SCENARIO"
fi
i=0
failed=0
for sc in $scenarios; do
  i=$((i + 1))
  xcrun simctl terminate "$SIM" "$bundle" >/dev/null 2>&1 || true
  xcrun simctl launch "$SIM" "$bundle" -BatwalkDemo "$sc" >/dev/null
  sleep 6
  xcrun simctl io "$SIM" screenshot "$out/$(printf '%02d' $i)-$sc.png" >/dev/null
  # A capture of the watch face / home screen means the app is gone: say so instead of
  # letting a wrong picture pass as the scenario.
  if xcrun simctl spawn "$SIM" launchctl list 2>/dev/null | grep -q "$bundle"; then
    echo "captured $platform/$sc"
  else
    echo "::warning::$platform/$sc: app was not running at capture time (crashed or exited)"
    failed=$((failed + 1))
  fi
done
# Crash reports from the simulator land in the host's DiagnosticReports; show the
# newest ones for this app so a launch crash is readable from the job log.
if [ "$failed" -gt 0 ]; then
  for report in $(ls -t ~/Library/Logs/DiagnosticReports/*.ips 2>/dev/null | head -n 6); do
    case "$(basename "$report")" in
      *[Bb]atwalk*)
        echo "::group::crash report $(basename "$report")"
        head -c 12000 "$report"; echo
        echo "::endgroup::";;
    esac
  done
fi
