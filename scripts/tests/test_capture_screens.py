"""Exercise capture success/failure with a simulated simctl, without a Mac."""
import os
from pathlib import Path
import shutil
import subprocess
import tempfile
import unittest


SCRIPT = Path(__file__).resolve().parents[1] / "capture-screens.sh"
BASH = os.environ.get("BATWALK_TEST_BASH") or shutil.which("bash")


@unittest.skipUnless(BASH, "bash is required")
class CaptureScreensTests(unittest.TestCase):
    def capture(self, exited=False):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "build/Build/Products/Debug-watchsimulator/Batwalk.app").mkdir(parents=True)
            (root / "Apps/Shared").mkdir(parents=True)
            (root / "Apps/Shared/DemoMode.swift").write_text(
                'let watchScenarios = ["home"] // scenarios:watch\n'
            )
            (root / "mockbin").mkdir()
            mocks = {
                "xcrun": '''#!/usr/bin/env bash
case "$2" in
  launch) printf 'com.aimanjack.batwalk.watchkitapp: %s\\n' "$FAKE_APP_PID";;
  io) touch "${@: -1}";;
  spawn)
    if [ "$4" = launchctl ]; then
      echo '- 6 application.com.aimanjack.batwalk.watchkitapp'
    else
      echo 'Batwalk: example diagnostic'
    fi;;
esac
''',
                "sleep": "#!/usr/bin/env bash\nexit 0\n",
            }
            for name, content in mocks.items():
                p = root / "mockbin" / name
                p.write_text(content, newline="\n")
                p.chmod(0o755)
            env = dict(os.environ, SIM="test-simulator", SCRIPT=SCRIPT.as_posix())
            pid = "999999999" if exited else "$$"
            result = subprocess.run(
                [BASH, "-c", 'export PATH="$PWD/mockbin:$PATH"; '
                 f'export FAKE_APP_PID={pid}; exec bash "$SCRIPT" watch out'],
                cwd=root, env=env, capture_output=True, text=True, timeout=15,
            )
            retained = (root / "out/01-home.png").exists()
            return result, retained

    def test_running_app_passes(self):
        result, retained = self.capture()
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertTrue(retained)
        self.assertIn("captured watch/home", result.stdout)

    def test_exited_app_fails_but_retains_evidence(self):
        result, retained = self.capture(exited=True)
        self.assertNotEqual(result.returncode, 0)
        self.assertTrue(retained)
        self.assertIn("app exited before capture", result.stdout)
        self.assertIn("retained images and diagnostics", result.stdout)


if __name__ == "__main__":
    unittest.main()
