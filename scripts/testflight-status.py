#!/usr/bin/env python3
"""Read-only Apple preflight and bounded TestFlight processing verification.

Requires PyJWT[crypto]==2.10.1. Credentials are read from ASC_KEY_ID,
ASC_ISSUER_ID and ASC_KEY_PATH; neither the key nor bearer token is logged.
No tester invitation, group assignment, review submission or build mutation.

Apple references:
https://developer.apple.com/documentation/appstoreconnectapi/generating-tokens-for-api-requests
https://developer.apple.com/documentation/appstoreconnectapi/get-v1-builds
https://developer.apple.com/documentation/appstoreconnectapi/get-v1-builds-_id_-buildbetadetail
https://developer.apple.com/documentation/appstoreconnectapi/internalbetastate
https://developer.apple.com/documentation/appstoreconnectapi/get-v1-betagroups
"""

import argparse
from datetime import datetime, timezone
import json
import os
from pathlib import Path
import re
import sys
import time
from urllib.error import HTTPError, URLError
from urllib.parse import quote, urlencode, urljoin, urlsplit
from urllib.request import HTTPRedirectHandler, Request, build_opener


API = "https://api.appstoreconnect.apple.com"
READY_STATES = {"READY_FOR_BETA_TESTING", "IN_BETA_TESTING"}
BLOCKED_STATES = {"PROCESSING_EXCEPTION", "MISSING_EXPORT_COMPLIANCE", "EXPIRED"}


class CheckError(Exception):
    """Only fixed, credential-free messages may be exposed to the caller."""


class APIError(CheckError):
    def __init__(self, status):
        self.status = status
        super().__init__(f"Apple API request failed (HTTP {status}).")


class RetryableError(CheckError):
    """Transient transport failure; bounded processing polling may retry."""


class NoRedirect(HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        # Never forward an Authorization header to a redirect target.
        return None


def safe_url(path):
    url = urljoin(API + "/", path)
    parts = urlsplit(url)
    if (parts.scheme != "https" or parts.netloc != "api.appstoreconnect.apple.com"
            or not parts.path.startswith("/v1/") or parts.fragment):
        raise CheckError("Apple pagination returned an unexpected destination.")
    return url


def credential_token(environ=None):
    environ = os.environ if environ is None else environ
    if not all(environ.get(name) for name in ("ASC_KEY_ID", "ASC_ISSUER_ID", "ASC_KEY_PATH")):
        raise CheckError("Missing Apple API credentials: ASC_KEY_ID, ASC_ISSUER_ID or ASC_KEY_PATH.")
    try:
        import jwt
    except ImportError:
        raise CheckError("Install PyJWT[crypto]==2.10.1 before checking Apple status.") from None
    try:
        key = Path(environ["ASC_KEY_PATH"]).read_text(encoding="utf-8")
        issued = int(time.time())
        return jwt.encode({"iss": environ["ASC_ISSUER_ID"], "iat": issued,
                           "exp": issued + 600, "aud": "appstoreconnect-v1"}, key,
                          algorithm="ES256", headers={"kid": environ["ASC_KEY_ID"], "typ": "JWT"})
    except Exception:
        # Library exceptions can include a private key, filename, or input.
        raise CheckError("Could not read or sign with the configured Apple API key.") from None


class AppleClient:
    def __init__(self, token_factory=credential_token, opener=None):
        self.token_factory = token_factory
        self.opener = opener or build_opener(NoRedirect())
        self._token = None
        self._refresh_at = 0
        self.deadline = None

    def get(self, path, params=None):
        url = safe_url(path)
        if params:
            url += ("&" if "?" in url else "?") + urlencode(params)
        remaining = self.deadline - time.monotonic() if self.deadline is not None else 20
        if remaining <= 0:
            raise RetryableError("Apple status check reached its time limit.")
        if self._token is None or time.monotonic() >= self._refresh_at:
            self._token = self.token_factory()
            self._refresh_at = time.monotonic() + 480
        request = Request(url, headers={"Authorization": "Bearer " + self._token,
                                       "Accept": "application/json"}, method="GET")
        try:
            with self.opener.open(request, timeout=min(20, remaining)) as response:
                payload = response.read(10_000_001)
            if len(payload) > 10_000_000:
                raise CheckError("Apple API response exceeded the size limit.")
            result = json.loads(payload)
            if not isinstance(result, dict):
                raise CheckError("Apple API returned an unexpected response.")
            return result
        except HTTPError as error:
            raise APIError(error.code) from None
        except (URLError, TimeoutError):
            raise RetryableError("Could not reach Apple API securely within the request timeout.") from None
        except (ValueError, UnicodeError):
            raise CheckError("Apple API returned an invalid JSON response.") from None

    def all(self, path, params=None):
        rows, visited = [], set()
        for _ in range(100):
            url = safe_url(path)
            if url in visited:
                raise CheckError("Apple pagination repeated a page.")
            visited.add(url)
            result = self.get(url, params)
            data = result.get("data")
            if not isinstance(data, list) or not all(isinstance(row, dict) for row in data):
                raise CheckError("Apple API returned an unexpected list response.")
            rows.extend(data)
            path = result.get("links", {}).get("next")
            if not path:
                return rows
            params = None
        raise CheckError("Apple pagination exceeded the safety limit.")


def integer_build(value):
    if not isinstance(value, str) or not re.fullmatch(r"[1-9][0-9]{0,3}", value):
        raise CheckError("Build numbers must be integers from 1 to 9999; review Apple's numbering before continuing.")
    return int(value)


def preflight(client, app_id, requested=""):
    rows = client.all("/v1/builds", {"filter[app]": app_id, "fields[builds]": "version", "limit": 200})
    latest = max((integer_build(row.get("attributes", {}).get("version")) for row in rows), default=0)
    chosen = integer_build(requested) if requested else latest + 1
    if chosen > 9999:
        raise CheckError("No unused integer build number remains in the configured 1 to 9999 range.")
    if chosen <= latest:
        raise CheckError(f"Requested build must be greater than Apple's latest build ({latest}).")
    return {"stage": "preflight", "app_id": app_id, "latest_build_number": latest,
            "build_number": chosen, "apple_access_confirmed": True,
            "note": "Number checked against all Apple builds. Run only one publisher at a time."}


def observe_build(client, app_id, number):
    rows = client.all("/v1/builds", {"filter[app]": app_id, "filter[version]": str(number),
                                    "fields[builds]": "version,processingState,expired,uploadedDate", "limit": 200})
    report = {"stage": "processing", "app_id": app_id, "build_number": number,
              "processing_state": "NOT_YET_VISIBLE", "internal_beta_state": None,
              "external_beta_state": None, "assigned_internal_group_count": None,
              "tester_availability": "unverified", "specific_tester_access_verified": False,
              "device_install_verified": False}
    if not rows:
        return report
    if len(rows) != 1:
        raise CheckError("Apple returned multiple builds with this number; select the release version explicitly before continuing.")
    row = rows[0]
    attrs = row.get("attributes", {})
    if str(attrs.get("version")) != str(number) or not isinstance(row.get("id"), str):
        raise CheckError("Apple returned a different build than requested.")
    report.update(processing_state=attrs.get("processingState", "UNKNOWN"), expired=attrs.get("expired", False))
    if report["expired"] or report["processing_state"] in {"FAILED", "INVALID"}:
        report["tester_availability"] = "unavailable"
        return report
    if report["processing_state"] != "VALID":
        return report
    build_id = quote(row["id"], safe="")
    detail = client.get(f"/v1/builds/{build_id}/buildBetaDetail", {
        "fields[buildBetaDetails]": "internalBuildState,externalBuildState"})
    beta_attrs = (detail.get("data") or {}).get("attributes", {})
    report["internal_beta_state"] = beta_attrs.get("internalBuildState")
    report["external_beta_state"] = beta_attrs.get("externalBuildState")
    if report["internal_beta_state"] in READY_STATES:
        report["tester_availability"] = "ready_for_internal_distribution"
        try:
            groups = client.all("/v1/betaGroups", {"filter[app]": app_id, "filter[builds]": row["id"],
                "filter[isInternalGroup]": "true", "fields[betaGroups]": "isInternalGroup", "limit": 200})
            count = sum(group.get("attributes", {}).get("isInternalGroup") is True for group in groups)
            report["assigned_internal_group_count"] = count
            if count > 0 and report["internal_beta_state"] == "IN_BETA_TESTING":
                report["tester_availability"] = "in_internal_testing_with_assigned_groups"
            report["assignment_check"] = "completed"
        except CheckError:
            report["assignment_check"] = "unavailable"
        report["note"] = "Apple processing and beta state are observed; a particular tester's access and device installation are not verified."
    elif report["internal_beta_state"] in BLOCKED_STATES:
        report["tester_availability"] = "requires_attention"
    return report


def poll_status(client, app_id, number, wait_seconds=900, interval_seconds=30,
                clock=time.monotonic, sleep=time.sleep):
    if not 0 <= wait_seconds <= 900 or not 1 <= interval_seconds <= 60:
        raise CheckError("Status polling allows 0 to 900 seconds, with a 1 to 60 second interval.")
    deadline = clock() + wait_seconds
    # A one-shot check still gets one bounded request sequence.
    if isinstance(client, AppleClient):
        client.deadline = time.monotonic() + (wait_seconds or 60)
    report = {"stage": "processing", "app_id": app_id, "build_number": number,
              "processing_state": "UNKNOWN", "tester_availability": "unverified",
              "specific_tester_access_verified": False, "device_install_verified": False}
    while True:
        try:
            report = observe_build(client, app_id, number)
        except APIError as error:
            if error.status not in {404, 429, 500, 502, 503, 504}:
                report.update(outcome="verification_failed", error=str(error))
                return report, 1
            report["last_check_error"] = str(error)
        except RetryableError as error:
            report["last_check_error"] = str(error)
        except CheckError as error:
            report.update(outcome="verification_failed", error=str(error))
            return report, 1
        else:
            if report.get("expired") or report["processing_state"] in {"FAILED", "INVALID"} or report["internal_beta_state"] in BLOCKED_STATES:
                report["outcome"] = "requires_attention"
                return report, 2
            if report["processing_state"] == "VALID" and report["internal_beta_state"] in READY_STATES:
                report["outcome"] = "processing_complete"
                return report, 0
        remaining = deadline - clock()
        if remaining <= 0:
            report["outcome"] = "not_confirmed_within_timeout"
            return report, 3
        sleep(min(interval_seconds, remaining))


def write_report(path, report):
    report = dict(report, checked_at=datetime.now(timezone.utc).isoformat())
    if path:
        target = Path(path)
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_text(json.dumps(report, indent=2) + "\n", encoding="utf-8")
    print(json.dumps(report, sort_keys=True))


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    sub = parser.add_subparsers(dest="command", required=True)
    before = sub.add_parser("preflight")
    before.add_argument("--requested-build", default="")
    before.add_argument("--github-env")
    after = sub.add_parser("status")
    after.add_argument("--build-number", required=True)
    after.add_argument("--wait-seconds", type=int, default=900)
    after.add_argument("--interval-seconds", type=int, default=30)
    for command in (before, after):
        command.add_argument("--app-id", default="6819895282")
        command.add_argument("--report")
    args = parser.parse_args(argv)
    try:
        if not re.fullmatch(r"[0-9]+", args.app_id):
            raise CheckError("App ID must be a numeric App Store Connect ID.")
        client = AppleClient()
        if args.command == "preflight":
            report = preflight(client, args.app_id, args.requested_build)
            if args.github_env:
                with Path(args.github_env).open("a", encoding="utf-8") as stream:
                    stream.write(f"BUILD_NUMBER={report['build_number']}\n")
            code = 0
        else:
            report, code = poll_status(client, args.app_id, integer_build(args.build_number),
                                       args.wait_seconds, args.interval_seconds)
        write_report(args.report, report)
        return code
    except CheckError as error:
        write_report(args.report, {"stage": args.command, "outcome": "verification_failed", "error": str(error)})
        return 1
    except (OSError, TypeError, KeyError):
        # Do not include paths, response bodies, or configuration values.
        print("Apple verification could not complete; check the configured files and response format.", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
