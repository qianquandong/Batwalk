import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("archive_check", Path(__file__).parents[1] / "verify-testflight-archive.py")
archive_check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(archive_check)


class TestFlightArchiveTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.archive = Path(self.temp.name) / "Batwalk.xcarchive"
        self.phone = self.archive / "Products/Applications/Batwalk.app"
        self.watch = self.phone / "Watch/Batwalk.app"
        self.widget = self.watch / "PlugIns/BatwalkComplication.appex"
        for path, suffix, platform in (
            (self.phone, "", "iPhoneOS"),
            (self.watch, ".watchkitapp", "WatchOS"),
            (self.widget, ".watchkitapp.widget", "WatchOS"),
        ):
            path.mkdir(parents=True)
            self.write(path / "Info.plist", {
                "CFBundleIdentifier": "com.aimanjack.batwalk" + suffix,
                "CFBundleVersion": "13", "CFBundleShortVersionString": "0.1.0",
                "CFBundleSupportedPlatforms": [platform], "CFBundleExecutable": "Binary",
            })
            (path / "Binary").write_bytes(b"fixture")
            self.write(path / "PrivacyInfo.xcprivacy", {"NSPrivacyTracking": False})
        self.update(self.phone, ITSAppUsesNonExemptEncryption=False)
        self.update(self.watch, WKApplication=True, WKCompanionAppBundleIdentifier="com.aimanjack.batwalk",
                    NSHealthShareUsageDescription="Reads steps", NSHealthUpdateUsageDescription="Read only")
        self.update(self.widget, NSExtension={"NSExtensionPointIdentifier": "com.apple.widgetkit-extension"})
        self.entitlements = Path(self.temp.name) / "entitlements.plist"
        self.write(self.entitlements, {"com.apple.developer.healthkit": True,
                                      "com.apple.developer.healthkit.background-delivery": True})

    def write(self, path, data):
        with path.open("wb") as stream:
            plistlib.dump(data, stream)

    def update(self, bundle, **changes):
        path = bundle / "Info.plist"
        value = archive_check.read_plist(path)
        self.write(path, dict(value, **changes))

    def verify(self):
        return archive_check.verify_archive(self.archive, "13", self.entitlements)

    def test_complete_embedded_watch_and_widget(self):
        report = self.verify()
        self.assertEqual(len(report["bundles"]), 3)
        self.assertEqual(report["build_number"], "13")

    def test_phone_only_archive_is_rejected(self):
        (self.watch / "Info.plist").unlink()
        with self.assertRaisesRegex(ValueError, "Missing or invalid"):
            self.verify()

    def test_animation_build_requires_both_apps_to_enable_flag(self):
        self.update(self.phone, BatwalkAnimationTesting="YES")
        with self.assertRaisesRegex(ValueError, "flag mismatch: Watch"):
            archive_check.verify_archive(self.archive, "13", self.entitlements, animation_testing=True)
        self.update(self.watch, BatwalkAnimationTesting="YES")
        report = archive_check.verify_archive(self.archive, "13", self.entitlements, animation_testing=True)
        self.assertTrue(report["animation_testing"])

    def test_normal_release_rejects_animation_testing(self):
        self.update(self.watch, BatwalkAnimationTesting="YES")
        with self.assertRaisesRegex(ValueError, "flag mismatch: Watch"):
            self.verify()

    def test_unbuilt_widget_is_rejected(self):
        (self.widget / "Binary").unlink()
        with self.assertRaisesRegex(ValueError, "Executable missing"):
            self.verify()

    def test_missing_widget_privacy_manifest_is_rejected(self):
        (self.widget / "PrivacyInfo.xcprivacy").unlink()
        with self.assertRaisesRegex(ValueError, "Missing or invalid"):
            self.verify()

    def test_mixed_build_versions_are_rejected(self):
        self.update(self.watch, CFBundleVersion="12")
        with self.assertRaisesRegex(ValueError, "Build number mismatch"):
            self.verify()

    def test_mixed_release_versions_are_rejected(self):
        self.update(self.widget, CFBundleShortVersionString="0.2.0")
        with self.assertRaisesRegex(ValueError, "Release version mismatch"):
            self.verify()

    def test_simulator_binary_is_rejected(self):
        self.update(self.watch, CFBundleSupportedPlatforms=["WatchSimulator"])
        with self.assertRaisesRegex(ValueError, "device platform"):
            self.verify()

    def test_wrong_companion_link_is_rejected(self):
        self.update(self.watch, WKCompanionAppBundleIdentifier="com.example.other")
        with self.assertRaisesRegex(ValueError, "not linked"):
            self.verify()

    def test_missing_health_background_entitlement_is_rejected(self):
        self.write(self.entitlements, {"com.apple.developer.healthkit": True})
        with self.assertRaisesRegex(ValueError, "background-delivery"):
            self.verify()


if __name__ == "__main__":
    unittest.main()
