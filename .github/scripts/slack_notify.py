#!/usr/bin/env python3
"""Post CI/CD status to Slack Incoming Webhook (Block Kit). No secrets printed. Requires SLACK_WEBHOOK_URL."""
import json
import os
import sys
import urllib.request


def _escape_mrkdwn(s: str) -> str:
    """Avoid breaking mrkdwn when values contain &, <, >."""
    return (
        str(s)
        .replace("&", "&amp;")
        .replace("<", "&lt;")
        .replace(">", "&gt;")
    )


def _color_hex(outcome: str) -> str:
    if outcome == "success":
        return "#2eb886"
    if outcome == "failure":
        return "#e01e5a"
    if outcome == "cancelled":
        return "#ecb22e"
    return "#439FE0"


def _build_blocks(
    title: str,
    outcome: str,
    repo: str,
    ref: str,
    sha: str,
    actor: str,
    run_url: str,
    extra: str,
) -> list:
    wf = os.environ.get("GITHUB_WORKFLOW", "").strip()
    run_no = os.environ.get("GITHUB_RUN_NUMBER", "").strip()
    run_id = os.environ.get("GITHUB_RUN_ID", "").strip()

    header_plain = title.strip()
    if len(header_plain) > 150:
        header_plain = header_plain[:147] + "…"

    fields = [
        {"type": "mrkdwn", "text": f"*Status*\n`{_escape_mrkdwn(outcome)}`"},
        {"type": "mrkdwn", "text": f"*Branch*\n`{_escape_mrkdwn(ref)}`"},
        {"type": "mrkdwn", "text": f"*Repository*\n`{_escape_mrkdwn(repo)}`"},
        {"type": "mrkdwn", "text": f"*Commit*\n`{_escape_mrkdwn(sha)}`"},
        {"type": "mrkdwn", "text": f"*Triggered by*\n{_escape_mrkdwn(actor)}"},
    ]
    if wf:
        wf_line = f"#{_escape_mrkdwn(run_no)}" if run_no else ""
        fields.append(
            {
                "type": "mrkdwn",
                "text": f"*Workflow*\n{_escape_mrkdwn(wf)} {wf_line}".strip(),
            }
        )

    blocks: list = [
        {"type": "header", "text": {"type": "plain_text", "text": header_plain, "emoji": False}},
        {"type": "section", "fields": fields},
    ]

    if extra.strip():
        blocks.append(
            {
                "type": "section",
                "text": {"type": "mrkdwn", "text": _escape_mrkdwn(extra.strip())},
            }
        )

    blocks.append({"type": "divider"})

    if run_url:
        btn = {
            "type": "button",
            "text": {"type": "plain_text", "text": "Open workflow run", "emoji": False},
            "url": run_url,
        }
        if outcome == "success":
            btn["style"] = "primary"
        elif outcome == "failure":
            btn["style"] = "danger"
        blocks.append({"type": "actions", "elements": [btn]})

    footer_bits = []
    if run_id:
        footer_bits.append(f"run `{_escape_mrkdwn(run_id)}`")
    if run_no:
        footer_bits.append(f"#{_escape_mrkdwn(run_no)}")
    footer_text = " · ".join(footer_bits) if footer_bits else ""
    if footer_text:
        blocks.append(
            {
                "type": "context",
                "elements": [
                    {
                        "type": "mrkdwn",
                        "text": f"GitHub Actions {footer_text}",
                    }
                ],
            }
        )

    return blocks


def main() -> int:
    url = os.environ.get("SLACK_WEBHOOK_URL", "").strip()
    if not url:
        print("Slack: SLACK_WEBHOOK_URL not set, skipping.")
        return 0

    outcome = os.environ.get("NOTIFY_OUTCOME", "unknown")
    title = os.environ.get("NOTIFY_TITLE", "Workflow")

    repo = os.environ.get("GITHUB_REPOSITORY", "")
    ref = os.environ.get("GITHUB_REF_NAME", "")
    sha = os.environ.get("GITHUB_SHA", "")[:7]
    actor = os.environ.get("GITHUB_ACTOR", "")
    run_url = os.environ.get("RUN_URL", "")
    extra = os.environ.get("NOTIFY_EXTRA", "")

    color = _color_hex(outcome)
    blocks = _build_blocks(title, outcome, repo, ref, sha, actor, run_url, extra)

    preview = f"{title} — {repo} ({ref}) · {outcome}"
    if len(preview) > 300:
        preview = preview[:297] + "…"

    payload = {
        "text": preview,
        "attachments": [
            {
                "color": color,
                "blocks": blocks,
            }
        ],
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
