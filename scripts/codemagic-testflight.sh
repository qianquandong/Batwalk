#!/usr/bin/env bash
# Keep Xcode's already-proven cloud signing flow; no private distribution key needed.
set -euo pipefail
set +x
: "${BATWALK_BUILD_NUMBER:?Run the TestFlight preflight first}"
: "${APP_STORE_CONNECT_KEY_IDENTIFIER:?Missing Apple integration}"
: "${APP_STORE_CONNECT_ISSUER_ID:?Missing Apple integration}"
: "${APP_STORE_CONNECT_PRIVATE_KEY:?Missing Apple integration}"
umask 077
key_dir=$(mktemp -d "${TMPDIR:-/tmp}/batwalk-signing.XXXXXX")
key_path="$key_dir/AuthKey.p8"
trap 'rm -f "$key_path"; rmdir "$key_dir"' EXIT
# Integration credentials can be a file reference rather than inline PEM text.
# Resolve without printing either the key or the reference into build logs.
python3 - "$key_path" <<'PY'
import os
import pathlib
import sys

try:
    value = os.environ["APP_STORE_CONNECT_PRIVATE_KEY"]
    if value.startswith("@file:"):
        value = pathlib.Path(os.path.expandvars(value[6:])).expanduser().read_text()
    elif value.startswith("@env:"):
        value = os.environ[value[5:]]
    if "-----BEGIN PRIVATE KEY-----" not in value:
        raise ValueError("Unsupported key format")
    with open(sys.argv[1], "x", encoding="utf-8") as stream:
        stream.write(value.strip() + "\n")
except Exception:
    sys.exit("Could not resolve the Apple integration private key securely.")
PY
openssl pkey -in "$key_path" -noout >/dev/null 2>&1 || {
  echo "The Apple integration key is not valid PEM." >&2
  exit 1
}
archive="$PWD/build/Batwalk.xcarchive"

bash scripts/ci-xcodebuild.sh \
  -project Batwalk.xcodeproj -scheme BatwalkPhone -configuration Release \
  -destination 'generic/platform=iOS' -archivePath "$archive" \
  CODE_SIGN_STYLE=Manual CODE_SIGN_IDENTITY=- AD_HOC_CODE_SIGNING_ALLOWED=YES \
  PROVISIONING_PROFILE_SPECIFIER= CURRENT_PROJECT_VERSION="$BATWALK_BUILD_NUMBER" archive

# Inspect the actual embedded Watch bundle, widget, versions, privacy and Health entitlements.
codesign --display --entitlements :- \
  "$archive/Products/Applications/Batwalk.app/Watch/Batwalk.app" \
  > build/reports/watch-archive-entitlements.plist
python3 scripts/verify-testflight-archive.py "$archive" \
  --build-number "$BATWALK_BUILD_NUMBER" \
  --watch-entitlements build/reports/watch-archive-entitlements.plist \
  --report build/reports/testflight-archive.json

# Xcode replaces the archive's ad-hoc signatures with Apple's managed distribution
# signature during export/upload, as in the successful GitHub TestFlight builds.
bash scripts/ci-xcodebuild.sh \
  -exportArchive -archivePath "$archive" \
  -exportOptionsPlist Config/ExportOptions.plist -exportPath "$PWD/build/export" \
  -allowProvisioningUpdates -authenticationKeyPath "$key_path" \
  -authenticationKeyID "$APP_STORE_CONNECT_KEY_IDENTIFIER" \
  -authenticationKeyIssuerID "$APP_STORE_CONNECT_ISSUER_ID"
echo "Build $BATWALK_BUILD_NUMBER uploaded. Apple processing and tester availability must still be checked."
