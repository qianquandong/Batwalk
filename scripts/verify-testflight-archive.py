#!/usr/bin/env python3
"""Reject incomplete iPhone/Watch archives before the upload step."""
import argparse
import json
import plistlib
from pathlib import Path


def read_plist(path):
    try:
        with path.open("rb") as stream:
            return plistlib.load(stream)
    except (OSError, plistlib.InvalidFileException) as error:
        raise ValueError(f"Missing or invalid archive plist: {path.name}") from error


def verify_archive(archive, build_number, watch_entitlements):
    phone = Path(archive) / "Products/Applications/Batwalk.app"
    watch = phone / "Watch/Batwalk.app"
    widget = watch / "PlugIns/BatwalkComplication.appex"
    expected = (
        (phone, "com.aimanjack.batwalk", "iPhoneOS"),
        (watch, "com.aimanjack.batwalk.watchkitapp", "WatchOS"),
        (widget, "com.aimanjack.batwalk.watchkitapp.widget", "WatchOS"),
    )
    bundles = []
    version = None
    for path, identifier, platform in expected:
        info = read_plist(path / "Info.plist")
        if info.get("CFBundleIdentifier") != identifier:
            raise ValueError(f"Wrong or missing bundle: {identifier}")
        if info.get("CFBundleVersion") != str(build_number):
            raise ValueError(f"Build number mismatch: {identifier}")
        current_version = info.get("CFBundleShortVersionString")
        if not current_version or (version is not None and current_version != version):
            raise ValueError(f"Release version mismatch: {identifier}")
        version = current_version
        if platform not in info.get("CFBundleSupportedPlatforms", []):
            raise ValueError(f"Archive is not for the expected device platform: {identifier}")
        executable = info.get("CFBundleExecutable", "")
        if not executable or Path(executable).name != executable or not (path / executable).is_file():
            raise ValueError(f"Executable missing: {identifier}")
        privacy = read_plist(path / "PrivacyInfo.xcprivacy")
        if privacy.get("NSPrivacyTracking") is not False:
            raise ValueError(f"Missing no-tracking privacy declaration: {identifier}")
        bundles.append({"bundle_id": identifier, "platform": platform, "privacy_manifest": True})

    phone_info = read_plist(phone / "Info.plist")
    watch_info = read_plist(watch / "Info.plist")
    widget_info = read_plist(widget / "Info.plist")
    if watch_info.get("WKCompanionAppBundleIdentifier") != expected[0][1] or not watch_info.get("WKApplication"):
        raise ValueError("Watch app is not linked to the iPhone companion")
    if widget_info.get("NSExtension", {}).get("NSExtensionPointIdentifier") != "com.apple.widgetkit-extension":
        raise ValueError("Watch widget extension is not configured")
    for key in ("NSHealthShareUsageDescription", "NSHealthUpdateUsageDescription"):
        if not watch_info.get(key):
            raise ValueError(f"Watch Health explanation missing: {key}")
    if phone_info.get("ITSAppUsesNonExemptEncryption") is not False:
        raise ValueError("Export compliance declaration requires review")
    entitlements = read_plist(Path(watch_entitlements))
    for key in ("com.apple.developer.healthkit", "com.apple.developer.healthkit.background-delivery"):
        if entitlements.get(key) is not True:
            raise ValueError(f"Required Watch entitlement missing: {key}")
    return {"version": version, "build_number": str(build_number), "bundles": bundles,
            "watch_health_entitlements": True, "stage": "pre-upload archive; distribution signing occurs during Xcode export"}


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive", type=Path)
    parser.add_argument("--build-number", required=True)
    parser.add_argument("--watch-entitlements", type=Path, required=True)
    parser.add_argument("--report", type=Path, required=True)
    args = parser.parse_args()
    try:
        result = verify_archive(args.archive, args.build_number, args.watch_entitlements)
    except ValueError as error:
        parser.exit(1, f"Archive validation failed: {error}\n")
    args.report.parent.mkdir(parents=True, exist_ok=True)
    args.report.write_text(json.dumps(result, indent=2) + "\n", encoding="utf-8")
    print(f"Verified iPhone, embedded Watch and widget for build {args.build_number}.")
