import importlib.util
from pathlib import Path
import plistlib
import tempfile
import unittest

spec = importlib.util.spec_from_file_location("archive_check", Path(__file__).parents[1] / "verify-game-center-archive.py")
archive_check = importlib.util.module_from_spec(spec)
spec.loader.exec_module(archive_check)


class GameCenterArchiveTests(unittest.TestCase):
    def test_enabled_archive_requires_both_runtime_flag_and_signed_entitlement(self):
        with tempfile.TemporaryDirectory() as folder:
            phone = Path(folder) / "Products/Applications/Batwalk.app"
            phone.mkdir(parents=True)
            info = phone / "Info.plist"
            info.write_bytes(plistlib.dumps({"BatwalkGameCenterEnabled": "YES"}))
            archive_check.verify(folder, True, lambda _: {archive_check.KEY: True})
            with self.assertRaisesRegex(ValueError, "signature"):
                archive_check.verify(folder, True, lambda _: {})
            info.write_bytes(plistlib.dumps({"BatwalkGameCenterEnabled": "NO"}))
            with self.assertRaisesRegex(ValueError, "runtime flag"):
                archive_check.verify(folder, True, lambda _: {archive_check.KEY: True})

    def test_disabled_phone_needs_no_entitlement_but_watch_must_stay_disabled(self):
        with tempfile.TemporaryDirectory() as folder:
            watch = Path(folder) / "Products/Applications/Batwalk.app/Watch/BatwalkWatch.app"
            watch.mkdir(parents=True)
            archive_check.verify(folder, False, lambda _: {})
            with self.assertRaisesRegex(ValueError, "Watch"):
                archive_check.verify(folder, False, lambda _: {archive_check.KEY: True})


if __name__ == "__main__":
    unittest.main()
