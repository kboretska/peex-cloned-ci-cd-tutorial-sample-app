# CI/CD Tutorial Sample App

[![CI](https://github.com/kboretska/peex-cloned-ci-cd-tutorial-sample-app/actions/workflows/docker_build_push.yml/badge.svg)](https://github.com/kboretska/peex-cloned-ci-cd-tutorial-sample-app/actions/workflows/docker_build_push.yml)
[![Release](https://github.com/kboretska/peex-cloned-ci-cd-tutorial-sample-app/actions/workflows/release_deploy.yml/badge.svg)](https://github.com/kboretska/peex-cloned-ci-cd-tutorial-sample-app/actions/workflows/release_deploy.yml)

Flask REST API sample used to learn CI/CD. Originally from this [Medium article](https://medium.com/rockedscience/docker-ci-cd-pipeline-with-github-actions-6d4cd1731030).

## What it does

- REST API (Flask), SQLite/Postgres, Alembic migrations
- Unit tests (`unittest`)
- GitHub Actions: tests, Docker build, push to **GHCR**, optional **SonarCloud**, **CodeQL**

## Workflows (short)

| Workflow | Role |
|----------|------|
| [docker_build_push.yml](.github/workflows/docker_build_push.yml) | Lint, test, push versioned image to GHCR |
| [release_deploy.yml](.github/workflows/release_deploy.yml) | Manual deploy: pull image tag + smoke test |
| [sonarcloud.yml](.github/workflows/sonarcloud.yml) | Tests + coverage + SonarCloud (needs [setup](#sonarcloud)) |
| [codeql-analysis.yml](.github/workflows/codeql-analysis.yml) | Security analysis |

Fork the repo? Update the badge URLs to your `owner/repo`.

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

GitHub can email you or show in-app alerts when workflows fail or succeed. Configure under [GitHub notification settings](https://github.com/settings/notifications) → **Actions**. No extra secrets in the repo.

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
