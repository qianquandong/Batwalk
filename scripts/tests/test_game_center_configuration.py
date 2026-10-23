import importlib.util
from pathlib import Path
import unittest


spec = importlib.util.spec_from_file_location("capabilities", Path(__file__).parents[1] / "configure-capabilities.py")
capabilities = importlib.util.module_from_spec(spec)
spec.loader.exec_module(capabilities)


class GameCenterConfigurationTests(unittest.TestCase):
    def test_default_build_has_no_game_center_entitlement(self):
        value = capabilities.specification()
        self.assertEqual(value["settings"]["base"]["BATWALK_GAME_CENTER_ENABLED"], "NO")
        self.assertNotIn("BatwalkPhone", value["targets"])

    def test_game_center_is_phone_only_and_preserves_cloud_entitlements(self):
        value = capabilities.specification(app_group=True, cloud_backup=True, game_center=True)
        phone = value["targets"]["BatwalkPhone"]["entitlements"]["properties"]
        self.assertIs(phone["com.apple.developer.game-center"], True)
        self.assertIn("com.apple.developer.icloud-container-identifiers", phone)
        self.assertNotIn("com.apple.developer.game-center", value["targets"]["BatwalkWatch"]["entitlements"]["properties"])
        self.assertEqual(value["settings"]["base"]["BATWALK_GAME_CENTER_ENABLED"], "YES")


if __name__ == "__main__":
    unittest.main()
