#!/usr/bin/env bash
# Runs xcodebuild, keeps the full log as a file, and on failure re-emits the
# compiler / signing errors as GitHub Actions annotations so they are readable
# from the run summary (and via the API) without downloading logs.
set -uo pipefail

log="${RUNNER_TEMP:-/tmp}/xcodebuild-$(date +%s).log"
xcodebuild "$@" >"$log" 2>&1
status=$?

if [ $status -ne 0 ]; then
  echo "xcodebuild failed with status $status — last 80 lines:"
  tail -n 80 "$log"
  # Up to 10 distinct error lines become annotations.
  grep -E "error:|error -|Error Domain|No profiles|No signing certificate|requires a provisioning profile|Provisioning profile|doesn't match|is not registered|ITMS-[0-9]+" "$log" \
    | sed -E 's/^[[:space:]]+//' | awk '!seen[$0]++' | head -n 10 \
    | while IFS= read -r line; do
        echo "::error::${line//$'\n'/ }"
      done
  # Whole log tail as one multi-line annotation (newlines encoded as %0A).
  echo "::warning title=xcodebuild log tail::$(tail -n 70 "$log" | sed -e 's/%/%25/g' -e 's/\r//g' | awk '{printf "%s%%0A", $0}')"
  # Export failures: the useful detail is in Apple's distribution logs.
  logdir=$(grep -oE "/[^ \"']+\.xcdistributionlogs" "$log" | head -n 1)
  find "${logdir:-${TMPDIR:-/tmp}}" -name "*.log" 2>/dev/null | head -n 5 | while IFS= read -r f; do
    echo "::warning title=$(basename "$f")::$(grep -iE "error|fail|denied|forbidden|401|403|409|not available|unauthor" "$f" | tail -n 25 | sed -e 's/%/%25/g' | awk '{printf "%s%%0A", $0}')"
  done
  find "${TMPDIR:-/tmp}" -name "*.xcdistributionlogs" -maxdepth 3 2>/dev/null | while IFS= read -r dir; do
    grep -rhoE "(NSLocalizedDescription|NSLocalizedFailureReason|NSLocalizedRecoverySuggestion|NSUnderlyingError|message|detail|title)[\" =:]+[^;}]{8,300}" "$dir" 2>/dev/null \
      | awk '!seen[$0]++' | head -n 10 \
      | while IFS= read -r line; do echo "::warning::${line}"; done
  done
  if [ -z "$(grep -E 'error' "$log" | head -n 1)" ]; then
    echo "::error::$(tail -n 3 "$log" | tr '\n' ' ')"
  fi
else
  grep -E "\*\* (ARCHIVE|EXPORT|BUILD) SUCCEEDED \*\*|Upload succeeded|Uploaded" "$log" || true
fi
exit $status
