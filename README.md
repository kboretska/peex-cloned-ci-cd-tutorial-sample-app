# CI/CD Tutorial Sample App

[![CI](https://github.com/kboretska/peex-cloned-ci-cd-tutorial-sample-app/actions/workflows/docker_build_push.yml/badge.svg)](https://github.com/kboretska/peex-cloned-ci-cd-tutorial-sample-app/actions/workflows/docker_build_push.yml)
[![Release](https://github.com/kboretska/peex-cloned-ci-cd-tutorial-sample-app/actions/workflows/release_deploy.yml/badge.svg)](https://github.com/kboretska/peex-cloned-ci-cd-tutorial-sample-app/actions/workflows/release_deploy.yml)

Flask REST API sample for learning CI/CD pipelines. Based on ideas from this [Medium article](https://medium.com/rockedscience/docker-ci-cd-pipeline-with-github-actions-6d4cd1731030).

---

## Overview

| Area | Details |
|------|---------|
| **Application** | REST API (Flask), SQLite or Postgres, Alembic migrations |
| **Tests** | Python `unittest` |
| **CI/CD** | GitHub Actions: lint, tests, Docker build, push to **GHCR** |
| **Optional** | **SonarCloud** analysis, **CodeQL** security scanning |

---

## Security (CI/CD)

This repository applies controls that fit a typical GitHub Actions setup. Tune branch protection, Actions policies, and secrets to match your organization.

### Secrets and configuration

- **Nothing sensitive is committed to git.** Tokens and webhook URLs are never hardcoded in YAML or scripts.
- **`GITHUB_TOKEN`** is short-lived and scoped by each workflow’s [`permissions`](https://docs.github.com/en/actions/security-guides/automatic-token-authentication#modifying-the-permissions-for-the-github_token). Workflows do not print it in logs.
- **Third-party secrets in GitHub:** [encrypted repository secrets](https://docs.github.com/en/actions/security-guides/using-secrets-in-github-actions) (for example `SONAR_TOKEN`, and optionally `SLACK_WEBHOOK_URL` as a fallback).
- **Slack webhook:** resolved by [slack-webhook-env](.github/actions/slack-webhook-env/action.yml):
  - **Preferred for coursework / cloud secret store:** read from **Azure Key Vault** using **OIDC** and a dedicated **Microsoft Entra application (service principal)** — no Azure client secret stored in GitHub (see [Azure workload identity and Key Vault](#azure-workload-identity-and-key-vault-slack-webhook)).
  - **Fallback:** if the five Azure inputs below are not all set, the workflow uses **`SLACK_WEBHOOK_URL`** from GitHub secrets only.
- Webhook values are [masked](https://docs.github.com/en/actions/writing-workflows/choosing-what-your-workflow-does/workflow-commands-for-github-actions#masking-a-value-in-a-log) in logs. If neither Key Vault nor `SLACK_WEBHOOK_URL` is available, Slack notify steps skip without failing the pipeline.

### Azure workload identity and Key Vault (Slack webhook)

Use this path when you need a **cloud service account** with **IAM on Azure** (least privilege) and **auditable** secret access.

**Concept:** you create an **App registration** in Microsoft Entra ID. It represents the CI “service principal”. You add a **federated credential** so GitHub Actions can obtain an Azure AD token via **OIDC** (no password in the repo). You grant that identity only **Key Vault Secrets User** on the vault that holds the Slack webhook string.

**GitHub repository configuration** (`Settings → Secrets and variables → Actions`):

| Type | Name | Purpose |
|------|------|---------|
| Secret | `AZURE_CLIENT_ID` | Application (client) ID of the Entra app used by GitHub Actions |
| Secret | `AZURE_TENANT_ID` | Directory (tenant) ID |
| Secret | `AZURE_SUBSCRIPTION_ID` | Subscription containing the Key Vault (used by `azure/login` scope) |
| Variable | `AZURE_KEY_VAULT_NAME` | Vault **name** from the portal (short name, not `*.vault.azure.net`) |
| Variable | `AZURE_KEY_VAULT_SECRET_NAME` | Name of the secret in Key Vault whose **value** is the full Slack Incoming Webhook URL |

Slack jobs declare **`id-token: write`** so the OIDC token can be issued for `Azure/login@v2`.

**Azure checklist (high level):**

1. **Key Vault** — create a secret (e.g. `slack-incoming-webhook`); value = full `https://hooks.slack.com/...` URL from Slack.
2. **Entra ID → App registrations → New registration** — name it e.g. `github-actions-ci-kv-read`; note **Application (client) ID** and **Directory (tenant) ID** for GitHub secrets above.
3. **Certificates & secrets → Federated credentials → Add** — scenario **GitHub Actions**; set **Organization**, **Repository**, and optionally **Entity** (branch / environment). Issuer: `https://token.actions.githubusercontent.com`. See GitHub’s [OIDC in Azure](https://docs.github.com/en/actions/how-tos/secure-your-work/security-harden-deployments/oidc-in-azure) for audience details.
4. **Key Vault → Access control (IAM) → Add role assignment** — role **[Key Vault Secrets User](https://learn.microsoft.com/en-us/azure/role-based-access-control/built-in-roles#key-vault-secrets-user)** on **this vault** for the app’s **enterprise application** (same client ID). This is the **minimal** permission needed to read one secret for Slack.
5. In GitHub, add the three **Secrets** and two **Variables** from the table.

If you **omit** any of the five Azure values, CI falls back to **`SLACK_WEBHOOK_URL`** only (still secure, still not in git).

### Least privilege (`GITHUB_TOKEN` and Azure)

Workflows declare the smallest `permissions` they need:

- Default: **`contents: read`**.
- **Build and push to GHCR** adds **`packages: write`** only on that job.
- **Manual release** uses **`packages: read`** only (pull image, smoke test).
- Slack notification jobs use **`contents: read`** and **`id-token: write`** (OIDC to Azure when Key Vault is configured); they do **not** get `packages: write`.

**Azure service principal:** only **Key Vault Secrets User** on the chosen vault (not Contributor on the subscription). Revisit IAM when you add new vaults or secrets.

### RBAC (who can change pipelines and artifacts)

| Control | Purpose |
|---------|---------|
| **Branch protection** | On `main` / `master`: required status checks (CI, CodeQL, Sonar if used), optional required reviews — **Settings → Branches**. |
| **[CODEOWNERS](.github/CODEOWNERS)** | Requires review for changes under `.github/workflows/` and `.github/actions/`. Replace `@kboretska` with your user or `@org/team`, then enable **Require review from Code Owners** if your org uses it. |
| **Fork pull requests** | Workflows from forks do not receive your repository secrets, which limits abuse of notify steps. |
| **`workflow_dispatch`** | [release_deploy.yml](.github/workflows/release_deploy.yml) is manual; restrict who can run workflows under **Settings → Actions → General** (org policies may apply). |

### Scanning strategy

| Layer | Tool | Location | Fail policy |
|-------|------|----------|-------------|
| Secrets in history | **Gitleaks** | [docker_build_push.yml](.github/workflows/docker_build_push.yml) (`test` job) | Fails on detected secrets (`fetch-depth: 0` for history). |
| SAST (Python) | **Bandit** | Same workflow | [bandit.yaml](bandit.yaml); **`-lll`** fails on **HIGH** and above. |
| SAST (Python) | **CodeQL** | [codeql-analysis.yml](.github/workflows/codeql-analysis.yml) | Results in **Security → Code scanning**; use [protection rules](https://docs.github.com/en/code-security/code-scanning/managing-code-scanning-alerts/about-code-scanning#about-alert-severity) to block merges on new Critical/High alerts. |
| Dependencies | **pip-audit** + OSV/CVSS | Same workflow | [pip_audit_critical_gate.py](.github/scripts/pip_audit_critical_gate.py) fails if any advisory has **CVSS v3 base ≥ 9.0**. |
| Container image | **Trivy** | After local image build | Fails on **CRITICAL** with a vendor fix (`exit-code: 1`). **`ignore-unfixed`** avoids blocking on Debian `will_not_fix` / no-package-yet OS issues; **`scanners: vuln`** limits the step to vulnerabilities (faster than full secret+vuln). The image **Dockerfile** runs **`apt-get upgrade`** so fixable OS CVEs are patched in the layer. |
| Quality (optional) | **SonarCloud** | [sonarcloud.yml](.github/workflows/sonarcloud.yml) | Quality Gate can fail the job. |

**Dependabot** ([dependabot.yml](.github/dependabot.yml)) opens PRs for `pip` and GitHub Actions updates (supply-chain hygiene, not a runtime gate).

**Performance:** Bandit, Gitleaks, and pip-audit run in the lightweight `test` job. Trivy runs only after a local image build on `push`. Severity is capped at **CRITICAL** for Trivy to balance signal versus runtime.

### Artifacts (GHCR)

Images are published to **GitHub Container Registry** with access tied to repository and organization roles. Private repositories keep packages private by default; adjust package visibility under **Packages** if needed. Release flow uses immutable-style tags (`build-*`, `sha-*`) for traceability and rollback — see [release_deploy.yml](.github/workflows/release_deploy.yml).

### Audit and periodic review

- **GitHub:** [Audit log](https://docs.github.com/en/organizations/keeping-your-organization-secure/managing-security-settings-for-your-organization/reviewing-the-audit-log-for-your-organization) (organization or enterprise) records workflow and security events when enabled.
- **Azure:** enable [Key Vault diagnostic logging](https://learn.microsoft.com/en-us/azure/key-vault/general/logging) to audit secret read operations; Entra sign-in / workload identity reports depend on tenant configuration.
- **Review cadence:** Re-check workflow `permissions`, federated credential subjects (repo / branch / environment), Key Vault IAM, Code scanning rules, and third-party tokens when you add jobs or integrations.

### Operations

- When adding jobs, extend `permissions` only as needed.
- **Rotate** Slack or Sonar credentials if exposed; update the Key Vault secret value and/or **`SLACK_WEBHOOK_URL`** in GitHub, and revoke the old Slack webhook in Slack.
- **Remediation:** If pip-audit’s CVSS gate or Trivy fails, upgrade dependencies or the base image ([Dockerfile](Dockerfile)), then re-run CI. The image uses **`python:3.8-slim-bookworm`** to reduce outdated OS CVE noise.

---

## Workflows

| Workflow | Role |
|----------|------|
| [docker_build_push.yml](.github/workflows/docker_build_push.yml) | Lint, test, optional Docker push to GHCR |
| [release_deploy.yml](.github/workflows/release_deploy.yml) | Manual: pull image tag from GHCR + smoke test |
| [sonarcloud.yml](.github/workflows/sonarcloud.yml) | Tests, coverage, SonarCloud (see [SonarCloud](#sonarcloud-optional)) |
| [codeql-analysis.yml](.github/workflows/codeql-analysis.yml) | CodeQL security analysis |

Forked this repo? Update badge URLs to your `owner/repo`.

### Status badges

- **CI** — last run of the main test and (on default-branch push) Docker push workflow.
- **Release** — last run of the manual deploy workflow; may show neutral until you run it once.

---

## Local development

### Requirements

- Python **3.8** (newer Python may break the pinned Flask 1.x stack)
- `pip`, venv or conda

On Linux, for Postgres client libraries: `sudo apt-get install libpq-dev gcc`

### Install and database

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

### Tests

```sh
python -m unittest discover
```

### Run locally

```sh
flask run
```

Production-style:

```sh
pip install -r requirements-server.txt
gunicorn app:app -b 0.0.0.0:8000
```

`GET /version` returns app version fields and `ci_run_number` when the image was built in CI.

---

## Versioning and images

- **[VERSION](VERSION)** — application SemVer (for example `0.1.0`). Bump when you release.
- **GHCR tags:** `build-<run_number>`, `sha-<short>`, `latest` on the default branch.
- **SemVer image tags** (`0.1.0`, `0.1`): push a Git tag `v0.1.0` (after updating `VERSION` if you want them aligned).
- Avoid pushing a bare `0.1.0` tag on every commit to `main`, or that tag will keep moving.

---

## Release and rollback

1. **Actions** → **Release - deploy by image version** → **Run workflow**
2. **image_version** — a tag from GHCR (`build-42`, `sha-abc1234`, `0.1.0` if you released with `v0.1.0`, or `latest`)
3. **Rollback:** run the workflow again with an older tag (no rebuild)

---

## SonarCloud (optional)

1. Import the repository at [sonarcloud.io](https://sonarcloud.io) (free for public repos).
2. **Disable Automatic Analysis** if you analyze only from GitHub Actions (Project settings → Analysis method).
3. Set **Organization** and **Project** keys in [sonar-project.properties](sonar-project.properties).
4. Create a token (SonarCloud → My Account → Security). Add **`SONAR_TOKEN`** under **Settings → Secrets and variables → Actions**.

If the scan fails, verify keys, token, and Quality Gate settings in SonarCloud.

---

## Notifications

### Slack (optional)

Uses [Slack Incoming Webhooks](https://api.slack.com/messaging/webhooks) — no Slack bot token in the repo.

1. In Slack, enable **Incoming Webhooks** for a channel and copy the **Webhook URL**.
2. Choose one:
   - **GitHub only:** add repository secret **`SLACK_WEBHOOK_URL`** with that URL, **or**
   - **Azure Key Vault:** store the URL as a Key Vault secret and set all **`AZURE_*`** values in GitHub as described under [Azure workload identity and Key Vault](#azure-workload-identity-and-key-vault-slack-webhook) (OIDC + Entra app; no Azure password in the repo).
3. On push to `main` / `master` or on pull requests, workflows run [slack_notify.py](.github/scripts/slack_notify.py) after [slack-webhook-env](.github/actions/slack-webhook-env/action.yml) resolves the webhook (skipped when no URL is available).

**Payload:** a [Block Kit](https://api.slack.com/block-kit) message (status, branch, repo, commit, actor, workflow, link to the run). CI and CD paths send separate messages so channels are not spammed with duplicates.

**Security:** never commit the webhook URL. Fork PRs from untrusted forks do not receive repository secrets, so Slack notify steps are skipped there.

### GitHub (email / in-app)

Configure under [GitHub notification settings](https://github.com/settings/notifications) → **Actions**. No repository secrets required.

---

## Docker

```sh
docker build -t app:local .
docker run -p 8000:8000 app:local
```

After CI (replace `OWNER/REPO`):

```sh
docker pull ghcr.io/OWNER/REPO:latest
docker run -p 8000:8000 ghcr.io/OWNER/REPO:build-<N>
```

---

## Heroku

```sh
heroku create
git push heroku master
heroku run flask db upgrade
heroku run python seed.py
```

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)

More: [Python on Heroku](https://devcenter.heroku.com/categories/python)
