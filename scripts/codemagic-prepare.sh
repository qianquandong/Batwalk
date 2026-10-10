#!/usr/bin/env bash
# Codemagic selects Xcode itself (its app names use '-' rather than GitHub's '_').
set -euo pipefail
mkdir -p build/reports "${RUNNER_TEMP:-/tmp/batwalk-ci-logs}"
xcodebuild -version | tee build/reports/toolchain.txt
xcode_major=$(awk '/^Xcode / { split($2, version, /[.]/); print version[1] }' build/reports/toolchain.txt)
if [[ ! "$xcode_major" =~ ^[0-9]+$ ]] || [ "$xcode_major" -lt 26 ]; then
  echo "Xcode 26 or newer is required. Check the workflow's environment.xcode setting." >&2
  exit 1
fi
swift --version | tee -a build/reports/toolchain.txt
if ! command -v xcodegen >/dev/null 2>&1; then
  brew install xcodegen
fi
xcodegen --version | tee -a build/reports/toolchain.txt
xcodegen generate
