import importlib.util
from pathlib import Path
import unittest

spec = importlib.util.spec_from_file_location("fallback", Path(__file__).parents[1] / "github-ci-fallback.py")
fallback = importlib.util.module_from_spec(spec)
spec.loader.exec_module(fallback)


class QuotaDetectionTests(unittest.TestCase):
    def test_actual_github_billing_annotation(self):
        jobs = [{"id": 1, "conclusion": "failure", "steps": []}, {"id": 2, "conclusion": "skipped", "steps": []}]
        annotation = {"1": [{"message": "The job was not started because recent account payments have failed or your spending limit needs to be increased."}]}
        self.assertTrue(fallback.quota_blocked(jobs, annotation))

    def test_included_minutes(self):
        self.assertTrue(fallback.quota_blocked(
            [{"id": 1, "conclusion": "failure", "steps": []}],
            {"1": [{"message": "You have exceeded your included minutes."}]},
        ))

    def test_started_test_failure_is_not_platform_block(self):
        self.assertFalse(fallback.quota_blocked(
            [{"id": 1, "conclusion": "failure", "steps": [{"name": "Tests", "conclusion": "failure"}]}],
            {"1": [{"message": "spending limit needs to be increased"}]},
        ))

    def test_mixed_failure_does_not_hide_code_error(self):
        self.assertFalse(fallback.quota_blocked(
            [{"id": 1, "conclusion": "failure", "steps": []}, {"id": 2, "conclusion": "failure", "steps": []}],
            {"1": [{"message": "recent account payments have failed"}], "2": [{"message": "Invalid workflow syntax"}]},
        ))

    def test_no_evidence_does_not_trigger(self):
        self.assertFalse(fallback.quota_blocked([{"id": 1, "conclusion": "failure", "steps": []}], {}))

    def test_cancelled_and_skipped_are_not_quota_failures(self):
        for conclusion in ("cancelled", "skipped", "success"):
            self.assertFalse(fallback.quota_blocked(
                [{"id": 1, "conclusion": conclusion, "steps": []}],
                {"1": [{"message": "spending limit needs to be increased"}]},
            ))


if __name__ == "__main__":
    unittest.main()
