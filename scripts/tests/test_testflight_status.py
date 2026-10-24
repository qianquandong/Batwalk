import importlib.util
import io
import json
from pathlib import Path
import tempfile
import unittest
from unittest.mock import patch
from urllib.error import HTTPError

spec = importlib.util.spec_from_file_location("tf_status", Path(__file__).parents[1] / "testflight-status.py")
status = importlib.util.module_from_spec(spec)
spec.loader.exec_module(status)


def build(number, processing="VALID", expired=False):
    return {"id": "build-id", "attributes": {"version": str(number), "processingState": processing, "expired": expired}}


class FakeClient:
    def __init__(self, builds=None, beta="IN_BETA_TESTING", groups=None):
        self.builds = builds or []
        self.beta = beta
        self.groups = groups if groups is not None else [{"attributes": {"isInternalGroup": True}}]
        self.calls = []

    def all(self, path, params=None):
        self.calls.append((path, params))
        return self.groups if path == "/v1/betaGroups" else self.builds

    def get(self, path, params=None):
        self.calls.append((path, params))
        return {"data": {"attributes": {"internalBuildState": self.beta, "externalBuildState": "READY_FOR_BETA_SUBMISSION"}}}


class FakeClock:
    def __init__(self):
        self.value = 0
        self.waits = []

    def now(self):
        return self.value

    def sleep(self, seconds):
        self.waits.append(seconds)
        self.value += seconds


class PreflightTests(unittest.TestCase):
    def test_maximum_number_not_lexical_or_upload_order(self):
        report = status.preflight(FakeClient([build(19), build(9), build(20)]), "6819895282")
        self.assertEqual(report["build_number"], 21)

    def test_requested_build_must_be_unused_and_above_latest(self):
        for requested in ("19", "18"):
            with self.assertRaisesRegex(status.CheckError, "greater than"):
                status.preflight(FakeClient([build(19)]), "6819895282", requested)
        self.assertEqual(status.preflight(FakeClient([build(19)]), "6819895282", "25")["build_number"], 25)

    def test_empty_app_starts_at_one(self):
        self.assertEqual(status.preflight(FakeClient(), "6819895282")["build_number"], 1)

    def test_unknown_numbering_and_overflow_fail_closed(self):
        for value in ("2.1", "0", "10000", "19\nBUILD_NUMBER=2"):
            with self.assertRaises(status.CheckError):
                status.preflight(FakeClient([build(value)]), "6819895282")
        with self.assertRaises(status.CheckError):
            status.preflight(FakeClient([build(9999)]), "6819895282")

    def test_cli_writes_only_validated_number_to_github_env(self):
        with tempfile.TemporaryDirectory() as folder:
            env = Path(folder) / "github-env"
            report = Path(folder) / "report.json"
            with patch.object(status, "AppleClient", return_value=FakeClient([build(19)])), patch("sys.stdout", new=io.StringIO()):
                result = status.main(["preflight", "--github-env", str(env), "--report", str(report)])
            self.assertEqual(result, 0)
            self.assertEqual(env.read_text(), "BUILD_NUMBER=20\n")
            self.assertTrue(json.loads(report.read_text())["apple_access_confirmed"])


class ProcessingTests(unittest.TestCase):
    def poll(self, client, seconds=60):
        clock = FakeClock()
        report, code = status.poll_status(client, "6819895282", 20, seconds, 30, clock.now, clock.sleep)
        return report, code, clock

    def test_valid_and_assigned_is_not_specific_tester_install_proof(self):
        report, code, _ = self.poll(FakeClient([build(20)]))
        self.assertEqual(code, 0)
        self.assertEqual(report["tester_availability"], "in_internal_testing_with_assigned_groups")
        self.assertFalse(report["specific_tester_access_verified"])
        self.assertFalse(report["device_install_verified"])
        self.assertNotIn("build-id", json.dumps(report))

    def test_ready_for_beta_does_not_claim_assigned_testers(self):
        report, code, _ = self.poll(FakeClient([build(20)], beta="READY_FOR_BETA_TESTING", groups=[]))
        self.assertEqual(code, 0)
        self.assertEqual(report["tester_availability"], "ready_for_internal_distribution")
        self.assertEqual(report["assigned_internal_group_count"], 0)

    def test_failed_invalid_expired_and_compliance_block_are_terminal(self):
        clients = [FakeClient([build(20, "FAILED")]), FakeClient([build(20, "INVALID")]),
                   FakeClient([build(20, expired=True)]), FakeClient([build(20)], beta="MISSING_EXPORT_COMPLIANCE")]
        for client in clients:
            report, code, clock = self.poll(client)
            self.assertEqual(code, 2)
            self.assertEqual(report["outcome"], "requires_attention")
            self.assertEqual(clock.waits, [])

    def test_processing_and_not_visible_stop_at_deadline(self):
        for client in (FakeClient([build(20, "PROCESSING")]), FakeClient()):
            report, code, clock = self.poll(client)
            self.assertEqual(code, 3)
            self.assertEqual(clock.value, 60)
            self.assertEqual(clock.waits, [30, 30])
            self.assertFalse(report["specific_tester_access_verified"])

    def test_processing_can_complete_on_later_poll(self):
        client = FakeClient([build(20, "PROCESSING")])
        clock = FakeClock()
        def advance(seconds):
            clock.sleep(seconds)
            client.builds = [build(20)]
        report, code = status.poll_status(client, "6819895282", 20, 60, 30, clock.now, advance)
        self.assertEqual(code, 0)
        self.assertEqual(clock.waits, [30])

    def test_api_auth_failure_is_not_retried_or_claimed_as_processing(self):
        client = FakeClient()
        client.all = lambda *args, **kwargs: (_ for _ in ()).throw(status.APIError(403))
        report, code, clock = self.poll(client)
        self.assertEqual(code, 1)
        self.assertEqual(report["outcome"], "verification_failed")
        self.assertFalse(clock.waits)

    def test_bad_credentials_or_response_shape_fail_without_waiting(self):
        client = FakeClient()
        client.all = lambda *args, **kwargs: (_ for _ in ()).throw(status.CheckError("Invalid configuration."))
        report, code, clock = self.poll(client)
        self.assertEqual(code, 1)
        self.assertEqual(report["outcome"], "verification_failed")
        self.assertFalse(clock.waits)

    def test_transient_transport_error_has_bounded_retries(self):
        client = FakeClient()
        client.all = lambda *args, **kwargs: (_ for _ in ()).throw(status.RetryableError("Connection timed out."))
        report, code, clock = self.poll(client)
        self.assertEqual(code, 3)
        self.assertEqual(clock.value, 60)
        self.assertEqual(report["last_check_error"], "Connection timed out.")

    def test_wait_bounds(self):
        with self.assertRaises(status.CheckError):
            self.poll(FakeClient(), 901)


class TransportTests(unittest.TestCase):
    def test_only_apple_https_pagination_allowed(self):
        for path in ("http://api.appstoreconnect.apple.com/v1/builds", "https://evil.example/v1/builds",
                     "https://api.appstoreconnect.apple.com@evil.example/v1/builds", "//evil.example/v1/builds"):
            with self.assertRaises(status.CheckError):
                status.safe_url(path)

    def test_follow_all_pages_to_avoid_reusing_hidden_build_number(self):
        client = status.AppleClient(token_factory=lambda: "unused")
        pages = iter([{"data": [build(9)], "links": {"next": status.API + "/v1/builds?cursor=next"}},
                      {"data": [build(19)], "links": {"next": None}}])
        client.get = lambda *args, **kwargs: next(pages)
        self.assertEqual(status.preflight(client, "6819895282")["build_number"], 20)

    def test_repeated_pagination_is_rejected(self):
        client = status.AppleClient(token_factory=lambda: "unused")
        client.get = lambda *args, **kwargs: {"data": [], "links": {"next": status.API + "/v1/builds"}}
        with self.assertRaisesRegex(status.CheckError, "repeated"):
            client.all("/v1/builds")

    def test_http_error_never_exposes_response_or_credentials(self):
        class Opener:
            def open(self, request, timeout):
                self.request = request
                raise HTTPError(request.full_url, 401, "private detail", {}, io.BytesIO(b"secret-key"))
        opener = Opener()
        client = status.AppleClient(token_factory=lambda: "secret-token", opener=opener)
        with self.assertRaises(status.APIError) as raised:
            client.get("/v1/builds")
        self.assertEqual(str(raised.exception), "Apple API request failed (HTTP 401).")
        self.assertEqual(opener.request.method, "GET")

    def test_missing_credentials_do_not_echo_supplied_values(self):
        with self.assertRaises(status.CheckError) as raised:
            status.credential_token({"ASC_KEY_ID": "private"})
        self.assertNotIn("private", str(raised.exception))

    @unittest.skipUnless(importlib.util.find_spec("jwt") and importlib.util.find_spec("cryptography"),
                         "JWT signing dependency is installed by the release workflow")
    def test_jwt_is_es256_signed_with_bounded_apple_claims(self):
        import jwt
        from cryptography.hazmat.primitives import serialization
        from cryptography.hazmat.primitives.asymmetric import ec
        key = ec.generate_private_key(ec.SECP256R1())
        with tempfile.TemporaryDirectory() as folder:
            path = Path(folder) / "fixture.p8"
            path.write_bytes(key.private_bytes(serialization.Encoding.PEM,
                                              serialization.PrivateFormat.PKCS8, serialization.NoEncryption()))
            with patch.object(status.time, "time", return_value=1700000000):
                token = status.credential_token({"ASC_KEY_ID": "fixture-key-id", "ASC_ISSUER_ID": "fixture-issuer",
                                                 "ASC_KEY_PATH": str(path)})
            claims = jwt.decode(token, key.public_key(), algorithms=["ES256"], audience="appstoreconnect-v1",
                                issuer="fixture-issuer", options={"verify_exp": False})
            self.assertEqual(claims["iat"], 1700000000)
            self.assertEqual(claims["exp"] - claims["iat"], 600)
            self.assertEqual(jwt.get_unverified_header(token)["kid"], "fixture-key-id")
            self.assertEqual(jwt.get_unverified_header(token)["alg"], "ES256")


if __name__ == "__main__":
    unittest.main()
