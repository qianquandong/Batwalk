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
  # letting a wrong picture pass as the scenario. (launchctl occasionally misses a live
  # app, so look twice before raising the flag.)
  if xcrun simctl spawn "$SIM" launchctl list 2>/dev/null | grep -q "$bundle" \
     || { sleep 1; xcrun simctl spawn "$SIM" launchctl list 2>/dev/null | grep -q "$bundle"; }; then
    echo "captured $platform/$sc"
  else
    echo "::warning::$platform/$sc: app not seen running at capture time — check the image (crash or exit?)"
    failed=$((failed + 1))
    echo "::group::simulator log around $sc"
    xcrun simctl spawn "$SIM" log show --last 40s --style compact \
      --predicate 'process CONTAINS[c] "batwalk" OR eventMessage CONTAINS[c] "batwalk"' 2>/dev/null \
      | grep -viE 'healthd|HealthKit|CoreData|analytics' | tail -n 60
    echo "::endgroup::"
  fi
done
# Crash reports from the simulator land in the host's DiagnosticReports; show the
# newest ones for this app so a launch crash is readable from the job log.
if [ "$failed" -gt 0 ]; then
  sleep 6 # the report is written a moment after the crash
  for report in $(ls -t ~/Library/Logs/DiagnosticReports/*.ips 2>/dev/null | head -n 4); do
    case "$(basename "$report")" in
      *[Bb]atwalk*)
        echo "::group::crash report $(basename "$report")"
        # Line 1 is a summary header; the body is JSON. Show the abort reason and the
        # faulting thread's top frames (image + symbol) rather than register dumps.
        tail -n +2 "$report" | jq -r '
          . as $r | ($r.faultingThread // 0) as $t |
          "exception: \($r.exception.type // "?") \($r.exception.signal // "")",
          "reason: \($r.asi // {} | tostring)",
          "last exception backtrace: \(($r.lastExceptionBacktrace // []) | length) frames",
          ($r.threads[$t].frames[:24][] |
            "  \($r.usedImages[.imageIndex].name // "?")  \(.symbol // ("+" + (.imageOffset|tostring)))")
        ' 2>/dev/null || head -c 6000 "$report"
        echo
        echo "::endgroup::";;
    esac
  done
fi
