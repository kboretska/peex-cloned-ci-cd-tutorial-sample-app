#!/usr/bin/env python3
"""Post CI/CD status to Slack Incoming Webhook. No secrets printed. Requires SLACK_WEBHOOK_URL."""
import json
import os
import sys
import urllib.request


def main() -> int:
    url = os.environ.get("SLACK_WEBHOOK_URL", "").strip()
    if not url:
        print("Slack: SLACK_WEBHOOK_URL not set, skipping.")
        return 0

    outcome = os.environ.get("NOTIFY_OUTCOME", "unknown")
    title = os.environ.get("NOTIFY_TITLE", "Workflow")
    if outcome == "success":
        color = "good"
    elif outcome in ("failure", "cancelled"):
        color = "danger" if outcome == "failure" else "warning"
    else:
        color = "#439FE0"

    repo = os.environ.get("GITHUB_REPOSITORY", "")
    ref = os.environ.get("GITHUB_REF_NAME", "")
    sha = os.environ.get("GITHUB_SHA", "")[:7]
    actor = os.environ.get("GITHUB_ACTOR", "")
    run_url = os.environ.get("RUN_URL", "")
    extra = os.environ.get("NOTIFY_EXTRA", "")

    lines = [
        f"*Outcome:* `{outcome}`",
        f"*Repo:* `{repo}`",
        f"*Ref:* `{ref}`",
        f"*Commit:* `{sha}`",
        f"*Actor:* `{actor}`",
    ]
    if extra:
        lines.append(str(extra))
    if run_url:
        lines.append(f"<{run_url}|Open workflow logs>")

    payload = {
        "attachments": [
            {
                "color": color,
                "title": title,
                "text": "\n".join(lines),
            }
        ]
    }
    data = json.dumps(payload).encode("utf-8")
    req = urllib.request.Request(
        url,
        data=data,
        headers={"Content-Type": "application/json"},
        method="POST",
    )
    with urllib.request.urlopen(req, timeout=30) as resp:
        if resp.status not in (200, 201):
            print("Slack returned HTTP", resp.status, file=sys.stderr)
            return 1
    print("Slack notification sent.")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
