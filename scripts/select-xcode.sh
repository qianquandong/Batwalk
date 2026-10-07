#!/usr/bin/env bash
# Select the newest installed Xcode 26+ (App Store uploads require the iOS 26 SDK).
set -euo pipefail
candidates=$(ls -d /Applications/Xcode_2[6-9]*.app 2>/dev/null | grep -v -i beta | sort -V || true)
if [ -z "$candidates" ]; then
  candidates=$(ls -d /Applications/Xcode_2[6-9]*.app 2>/dev/null | sort -V || true)
fi
if [ -z "$candidates" ]; then
  echo "::error::No Xcode 26+ on this runner. Installed: $(ls -d /Applications/Xcode*.app | xargs -n1 basename | tr '\n' ' ')"
  exit 1
fi
xcode=$(echo "$candidates" | tail -n 1)
sudo xcode-select -s "$xcode/Contents/Developer"
echo "::notice::Using $(basename "$xcode") — $(xcodebuild -version | tr '\n' ' ')"
