#!/usr/bin/env bash
# Read-only Apple access check. Do not spend build minutes with missing credentials.
set -euo pipefail
set +x
for name in APP_STORE_CONNECT_KEY_IDENTIFIER APP_STORE_CONNECT_ISSUER_ID APP_STORE_CONNECT_PRIVATE_KEY APP_STORE_APPLE_ID; do
  if [ -z "${!name:-}" ]; then
    echo "Missing $name. Check the Batwalk TestFlight integration and workflow variables in Codemagic." >&2
    exit 1
  fi
done
case "$APP_STORE_CONNECT_PRIVATE_KEY" in
  *"BEGIN PRIVATE KEY"*) ;;
  *) echo "The Apple integration does not contain a valid .p8 key." >&2; exit 1 ;;
esac
[[ "$APP_STORE_APPLE_ID" =~ ^[0-9]+$ ]] || { echo "APP_STORE_APPLE_ID must be the numeric Batwalk Apple ID." >&2; exit 1; }
latest=$(app-store-connect get-latest-testflight-build-number "$APP_STORE_APPLE_ID")
[[ "$latest" =~ ^[0-9]+$ ]] || { echo "Could not read Batwalk's existing integer TestFlight build number." >&2; exit 1; }
# The existing GitHub workflow used an integer counter; continue from Apple's value.
next=$((10#$latest + 1))
[ "$next" -le 9999 ] || { echo "Review the build numbering scheme before continuing." >&2; exit 1; }
echo "BATWALK_BUILD_NUMBER=$next" >> "$CM_ENV"
echo "Apple access confirmed. Next Batwalk build: $next."
