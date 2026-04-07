#!/usr/bin/env python3
"""
Run pip-audit JSON, then resolve severities via OSV. Exit 1 only if any
vulnerability has CVSS v3 base score >= 9.0 (CRITICAL). No secrets printed.
"""
import json
import subprocess
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Dict, List, Optional, Set


CRITICAL_MIN = 9.0
OSV_DELAY_SEC = 0.15


def _load_cvss3():
    try:
        from cvss import CVSS3
    except ImportError as e:
        print("Install the `cvss` package: pip install cvss", file=sys.stderr)
        raise SystemExit(2) from e
    return CVSS3


def _pip_audit_json() -> Dict:
    p = subprocess.run(
        [
            sys.executable,
            "-m",
            "pip_audit",
            "-r",
            "requirements.txt",
            "-f",
            "json",
        ],
        capture_output=True,
        text=True,
        check=False,
    )
    if not p.stdout.strip():
        print(p.stderr, file=sys.stderr)
        raise SystemExit(p.returncode if p.returncode != 0 else 1)
    return json.loads(p.stdout)


def _collect_vuln_ids(data: Dict) -> Set[str]:
    ids: Set[str] = set()
    for dep in data.get("dependencies", []):
        for v in dep.get("vulns") or []:
            vid = v.get("id")
            if vid:
                ids.add(vid)
    return ids


def _fetch_osv(vuln_id: str) -> Optional[Dict]:
    safe = urllib.parse.quote(vuln_id, safe="")
    url = f"https://api.osv.dev/v1/vulns/{safe}"
    req = urllib.request.Request(url, headers={"Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            return json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        if e.code == 404:
            return None
        raise
    except urllib.error.URLError as e:
        print(f"OSV request failed for {vuln_id}: {e}", file=sys.stderr)
        raise


def _max_cvss3_base(CVSS3, osv: Dict) -> Optional[float]:
    best: float | None = None
    for sev in osv.get("severity") or []:
        if sev.get("type") != "CVSS_V3":
            continue
        score = sev.get("score") or ""
        if not score.startswith("CVSS:3"):
            continue
        try:
            c = CVSS3(score)
            base = float(c.scores()[0])
        except Exception:
            continue
        if best is None or base > best:
            best = base
    return best


def main() -> int:
    CVSS3 = _load_cvss3()
    try:
        data = _pip_audit_json()
    except json.JSONDecodeError as e:
        print("pip-audit did not return valid JSON:", e, file=sys.stderr)
        return 1

    ids = _collect_vuln_ids(data)
    if not ids:
        print("pip-audit: no vulnerabilities reported (or empty vuln list).")
        return 0

    critical: List[str] = []
    for i, vid in enumerate(sorted(ids)):
        if i and OSV_DELAY_SEC:
            time.sleep(OSV_DELAY_SEC)
        osv = _fetch_osv(vid)
        if not osv:
            continue
        mx = _max_cvss3_base(CVSS3, osv)
        if mx is not None and mx >= CRITICAL_MIN:
            critical.append(f"{vid} (CVSS base {mx:.1f})")

    if critical:
        print("CRITICAL dependency vulnerabilities (CVSS base >= 9.0):", file=sys.stderr)
        for c in critical:
            print(f"  - {c}", file=sys.stderr)
        return 1

    print(
        f"pip-audit reported {len(ids)} unique advisories; none rated CRITICAL (CVSS base >= 9.0) via OSV."
    )
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
