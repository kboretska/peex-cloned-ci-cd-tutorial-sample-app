# CI/CD Tutorial Sample App

[![CI](https://github.com/kboretska/peex-cloned-ci-cd-tutorial-sample-app/actions/workflows/docker_build_push.yml/badge.svg)](https://github.com/kboretska/peex-cloned-ci-cd-tutorial-sample-app/actions/workflows/docker_build_push.yml)
[![Release](https://github.com/kboretska/peex-cloned-ci-cd-tutorial-sample-app/actions/workflows/release_deploy.yml/badge.svg)](https://github.com/kboretska/peex-cloned-ci-cd-tutorial-sample-app/actions/workflows/release_deploy.yml)

Flask REST API sample used to learn CI/CD. Originally from this [Medium article](https://medium.com/rockedscience/docker-ci-cd-pipeline-with-github-actions-6d4cd1731030).

## What it does

- REST API (Flask), SQLite/Postgres, Alembic migrations
- Unit tests (`unittest`)
- GitHub Actions: tests, Docker build, push to **GHCR**, optional **SonarCloud**, **CodeQL**

## Security (CI/CD)

This repo applies common controls suitable for GitHub Actions; adjust for your org’s policies.

### Secrets and configuration

- **No secrets in git.** Optional integrations use **GitHub Actions encrypted secrets** only: `SLACK_WEBHOOK_URL`, `SONAR_TOKEN`. The workflow uses `secrets.GITHUB_TOKEN` (ephemeral, scoped to the run) for GHCR — never pasted into logs by our scripts.
- **Slack:** webhook URL lives only in **Settings → Secrets and variables → Actions**. The notify script does not print secret values.
- **Retrieval / audit:** GitHub records secret *usage* at the org/repo level where your plan allows ([audit log](https://docs.github.com/en/organizations/keeping-your-organization-secure/managing-security-settings-for-your-organization/reviewing-the-audit-log-for-your-organization) for orgs). Treat GitHub as the secret store for this pipeline.

### Least privilege (`GITHUB_TOKEN`)

Workflows declare minimal **`permissions`**. The main CI workflow defaults to `contents: read`; only the **Build and push to GHCR** job adds `packages: write`. Slack notification jobs stay on `contents: read` so they cannot push packages.

### RBAC (who can change what)

- **Branch protection** on `main`/`master`: required checks, optional required reviews — configure in **Settings → Branches** (repo or org).
- **CODEOWNERS:** optional file to require review for `.github/workflows/` — add `@team` or `@username` your org trusts.
- **Fork PRs:** workflows from forks do not receive your repository secrets, limiting abuse.

### Scanning strategy

| Layer | Tool | Where | Fail policy |
|-------|------|--------|-------------|
| SAST (Python) | **CodeQL** | [codeql-analysis.yml](.github/workflows/codeql-analysis.yml) | Findings in Security tab; configure required checks / code scanning rules in repo settings. |
| Dependencies (PyPI) | **pip-audit** + **OSV** + **CVSS** | [docker_build_push.yml](.github/workflows/docker_build_push.yml) | [pip_audit_critical_gate.py](.github/scripts/pip_audit_critical_gate.py) fails the job if any advisory has **CVSS v3 base ≥ 9.0** (CRITICAL) per [OSV](https://osv.dev/). Other reported CVEs still appear in `pip-audit` JSON for remediation. |
| Container image | **Trivy** | Same workflow after local image build | Fails on **CRITICAL** image vulns (`exit-code: 1`). |
| Quality / policy | **SonarCloud** (optional) | [sonarcloud.yml](.github/workflows/sonarcloud.yml) | Quality Gate can fail the job when enabled. |

**Dependabot** ([dependabot.yml](.github/dependabot.yml)) opens PRs for `pip` and **GitHub Actions** updates — proactive dependency hygiene (not a runtime scanner).

### Artifacts (GHCR)

Images go to **GitHub Container Registry** with permissions tied to repo/org roles. Private repos keep packages private by default; public repos expose images publicly — choose visibility under **Packages** settings.

### Operations

- **Review permissions** when adding new jobs (keep scopes minimal); re-check workflow `permissions` when GitHub adds features or you add integrations.
- **Rotate** Sonar/Slack credentials if exposed; revoke in the upstream service and update GitHub secrets.
- **Remediation:** if the CVSS gate or Trivy fails, bump dependencies or the base image (see [Dockerfile](Dockerfile)), then re-run CI. The image uses **`python:3.8-slim-bookworm`** instead of EOL Ubuntu 18.04 to reduce OS CVE noise and speed up patching.

## Workflows (short)

| Workflow | Role |
|----------|------|
| [docker_build_push.yml](.github/workflows/docker_build_push.yml) | Lint, test, push versioned image to GHCR |
| [release_deploy.yml](.github/workflows/release_deploy.yml) | Manual deploy: pull image tag + smoke test |
| [sonarcloud.yml](.github/workflows/sonarcloud.yml) | Tests + coverage + SonarCloud (needs [setup](#sonarcloud)) |
| [codeql-analysis.yml](.github/workflows/codeql-analysis.yml) | Security analysis |

Fork the repo? Update the badge URLs to your `owner/repo`.

### Status badges

- **CI** — last run of [docker_build_push.yml](.github/workflows/docker_build_push.yml) (lint, tests, and on `push` also Docker push to GHCR). The SVG refreshes when a run finishes; open the badge link for history.
- **Release** — last run of [release_deploy.yml](.github/workflows/release_deploy.yml) (manual deploy / smoke test). Until you run it once, it may show “no status” or neutral.

## Requirements

- Python **3.8** (local use; 3.12+ may break with pinned Flask 1.x stack)
- pip, venv or conda

For Postgres deps on Linux: `sudo apt-get install libpq-dev gcc`

## Install & database

```sh
python -m venv venv
source venv/bin/activate   # Windows: venv\Scripts\activate
pip install -r requirements.txt
```

Optional: set `DATABASE_URL`. Otherwise SQLite is used.

```sh
flask db upgrade
python seed.py
```

## Tests

```sh
python -m unittest discover
```

## Run locally

```sh
flask run
```

Production-style:

```sh
pip install -r requirements-server.txt
gunicorn app:app -b 0.0.0.0:8000
```

`GET /version` returns app version fields and `ci_run_number` when built in CI.

## Versioning & images

- **[VERSION](VERSION)** — app SemVer (e.g. `0.1.0`). Bump when you release.
- **Image tags in GHCR:** `build-<run>`, `sha-<short>`, `latest` on default branch. Tags are immutable.
- **SemVer image tags** (`0.1.0`, `0.1`): push a Git tag `v0.1.0` (after updating `VERSION` if you want them to match).
- Do not push a bare `0.1.0` tag on every commit to `main` — it would overwrite the same tag.

## Release & rollback

1. **Actions** → **Release - deploy by image version** → **Run workflow**
2. **image_version** = a tag from GHCR (`build-42`, `sha-xxx`, `0.1.0` if you released with `v0.1.0`, or `latest`)
3. **Rollback:** run again with an older tag (no rebuild)

## SonarCloud

1. Import this repo at [sonarcloud.io](https://sonarcloud.io) (free for public repos).
2. **Disable Automatic Analysis** if you use CI (Project settings → Analysis method) — only one mode.
3. Copy **Organization** and **Project** keys into [sonar-project.properties](sonar-project.properties).
4. Create a token (SonarCloud → My Account → Security). Add **`SONAR_TOKEN`** in GitHub → **Settings → Secrets → Actions**.

If the scan fails: check keys, token, and Quality Gate settings in SonarCloud.

## Notifications

### Slack (optional)

Posts use [Incoming Webhooks](https://api.slack.com/messaging/webhooks) — no Slack token in the workflow file.

1. In Slack: create an app or use **Incoming Webhooks**, pick a channel, copy the **Webhook URL**.
2. In GitHub: **Settings → Secrets and variables → Actions → New repository secret** → name **`SLACK_WEBHOOK_URL`**, value = the webhook URL.
3. Push to `main`/`master` or open a PR: workflows run [`.github/scripts/slack_notify.py`](.github/scripts/slack_notify.py) after CI/CD steps (skipped if the secret is unset).

**What gets sent:** a [Block Kit](https://api.slack.com/block-kit) card — header title, two-column fields (status, branch, repo, commit, actor, workflow), optional notes, then a **Open workflow run** button and a small footer (`run` id / number). **Success** uses a green sidebar; **failure** red; **cancelled** amber. **CI** and **CD** are separate messages (lint/tests vs Docker push vs manual release deploy), so you are not flooded on every commit with duplicate text.

**Security:** do not commit the webhook URL. Do not paste secrets into Slack messages from workflows. **Fork PRs** from untrusted forks do not receive repository secrets, so Slack notify steps are skipped there.

### GitHub (email / in-app)

Configure under [GitHub notification settings](https://github.com/settings/notifications) → **Actions**. Works without repo secrets.

## Docker

```sh
docker build -t app:local .
docker run -p 8000:8000 app:local
```

From GHCR after CI (replace owner/repo):

```sh
docker pull ghcr.io/OWNER/REPO:latest
docker run -p 8000:8000 ghcr.io/OWNER/REPO:build-<N>
```

## Heroku

```sh
heroku create
git push heroku master
heroku run flask db upgrade
heroku run python seed.py
```

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)

More: [Python on Heroku](https://devcenter.heroku.com/categories/python)
