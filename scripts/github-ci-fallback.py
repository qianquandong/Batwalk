#!/usr/bin/env python3
"""Read-only candidates for the Codex GitHub -> Codemagic monitor.

Uses the existing gh login. Never reads or copies its token, and never starts builds.
Only current main/open same-repository PR heads are considered.
"""
import json
import subprocess
from urllib.parse import quote, urlencode

REPOSITORY = "qianquandong/Batwalk"
BLOCK_MESSAGES = (
    "recent account payments have failed",
    "spending limit needs to be increased",
    "exceeded your included minutes",
    "exceeded its spending limit",
)


def quota_blocked(jobs, annotations):
    """Require every failed job to be unstarted with explicit billing evidence."""
    failed = [job for job in jobs if job.get("conclusion") == "failure"]
    if not failed:
        return False
    for job in failed:
        if job.get("steps"):
            return False
        messages = annotations.get(str(job["id"]), [])
        if not any(
            phrase in annotation.get("message", "").lower()
            for annotation in messages
            for phrase in BLOCK_MESSAGES
        ):
            return False
    return True


def api(path, paged=False):
    command = ["gh", "api", f"repos/{REPOSITORY}/{path}"]
    if paged:
        command.extend(["--paginate", "--slurp"])
    result = subprocess.run(command, text=True, encoding="utf-8", capture_output=True, check=True)
    value = json.loads(result.stdout)
    return [item for page in value for item in page] if paged else value


def candidates():
    main = api("branches/main")
    heads = {main["name"]: main["commit"]["sha"]}
    for pull in api("pulls?state=open&per_page=100", paged=True):
        head = pull["head"]
        if (head.get("repo") or {}).get("full_name") == REPOSITORY:
            heads[head["ref"]] = head["sha"]
    result = []
    for branch, sha in heads.items():
        query = urlencode({"head_sha": sha, "branch": branch, "per_page": 1})
        runs = api(f"actions/workflows/ci.yml/runs?{query}")["workflow_runs"]
        if not runs or runs[0]["status"] != "completed" or runs[0]["conclusion"] != "failure":
            continue
        run = runs[0]
        # Page through jobs rather than assuming a fixed job count.
        jobs_result = subprocess.run(
            ["gh", "api", f"repos/{REPOSITORY}/actions/runs/{run['id']}/jobs?per_page=100", "--paginate", "--slurp"],
            text=True, encoding="utf-8", capture_output=True, check=True,
        )
        jobs = [job for page in json.loads(jobs_result.stdout) for job in page["jobs"]]
        annotations = {}
        for job in jobs:
            if job.get("conclusion") == "failure" and not job.get("steps"):
                check_id = job["check_run_url"].rsplit("/", 1)[-1]
                annotations[str(job["id"])] = api(f"check-runs/{check_id}/annotations?per_page=100", paged=True)
        if not quota_blocked(jobs, annotations):
            continue
        root = api(f"contents?ref={quote(sha, safe='')}")
        if not any(item["name"] == "codemagic.yaml" and item["type"] == "file" for item in root):
            continue
        result.append({
            "repository": REPOSITORY,
            "branch": branch,
            "sha": sha,
            "github_run_id": run["id"],
            "github_url": run["html_url"],
            "workflow": "batwalk-verify",
            "reason": "GitHub explicitly reports billing/minute limits before job execution",
        })
    return result


if __name__ == "__main__":
    print(json.dumps({"candidates": candidates()}, indent=2))
