#!/usr/bin/env python3
"""Check only Game Center flags in the signed archive; never print profiles."""
import os
from pathlib import Path
import plistlib
import subprocess
import sys


KEY = "com.apple.developer.game-center"


def signed_entitlements(bundle):
    result = subprocess.run(
        ["codesign", "-d", "--entitlements", ":-", str(bundle)],
        check=True, capture_output=True,
    )
    return plistlib.loads(result.stdout) if result.stdout.strip() else {}


def verify(archive, enabled, read_entitlements=signed_entitlements):
    phone = Path(archive) / "Products/Applications/Batwalk.app"
    if not phone.is_dir():
        raise ValueError("Missing iPhone app in archive")
    if enabled:
        with (phone / "Info.plist").open("rb") as handle:
            info = plistlib.load(handle)
        if str(info.get("BatwalkGameCenterEnabled", "")).lower() not in ("yes", "true", "1"):
            raise ValueError("Game Center runtime flag is not enabled in the archived iPhone app")
        if read_entitlements(phone).get(KEY) is not True:
            raise ValueError("Archived iPhone signature is missing the Game Center entitlement")
    watch = phone / "Watch"
    for bundle in list(watch.rglob("*.app")) + list(watch.rglob("*.appex")):
        if read_entitlements(bundle).get(KEY):
            raise ValueError("Game Center must not be enabled in an embedded Watch bundle")


if __name__ == "__main__":
    verify(sys.argv[1], os.environ.get("BATWALK_GAME_CENTER") == "true")
    print("Archived Game Center entitlement scope and runtime flag verified.")
