#!/usr/bin/env python3
"""Generate an XcodeGen overlay; portal registration/profiles remain separate."""
import argparse
import json
from pathlib import Path

def specification(app_group=False, cloud_backup=False):
    targets = {}
    if app_group:
        for name in ("BatwalkWatch", "BatwalkComplication"):
            folder = "Watch" if name == "BatwalkWatch" else "Complication"
            targets[name] = {"entitlements": {
                "path": f"Apps/{folder}/{name}.entitlements",
                "properties": {"com.apple.security.application-groups": ["group.com.aimanjack.batwalk"]}}}
    if cloud_backup:
        for name, folder in (("BatwalkWatch", "Watch"), ("BatwalkPhone", "Phone")):
            entry = targets.setdefault(name, {})
            entitlements = entry.setdefault("entitlements", {"path": f"Apps/{folder}/{name}.entitlements", "properties": {}})
            entitlements["properties"].update({
                "com.apple.developer.icloud-container-identifiers": ["iCloud.com.aimanjack.batwalk"],
                "com.apple.developer.icloud-services": ["CloudKit"],
                "aps-environment": "development"})
        targets["BatwalkPhone"]["info"] = {"properties": {"UIBackgroundModes": ["remote-notification"]}}
    return {"include": ["project.yml"], "settings": {"base": {
        "BATWALK_APP_GROUP_ENABLED": "YES" if app_group else "NO",
        "BATWALK_CLOUD_BACKUP_ENABLED": "YES" if cloud_backup else "NO"}}, "targets": targets}

if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--app-group", action="store_true")
    parser.add_argument("--cloud-backup", action="store_true")
    args = parser.parse_args()
    destination = Path(__file__).resolve().parent.parent / "project.capabilities.json"
    destination.write_text(json.dumps(specification(args.app_group, args.cloud_backup), indent=2) + "\n", encoding="utf-8")
    print("Generated project.capabilities.json. Run xcodegen generate --spec project.capabilities.json.")
    print("Register enabled identifiers and refresh profiles before signed device builds.")
