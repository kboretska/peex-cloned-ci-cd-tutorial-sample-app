# CD/CI Tutorial Sample Application ⚙

<!-- Workflow status badges (оновлюються після кожного запуску Actions на default branch). -->
[![CI — test and push](https://github.com/kboretska/peex-cloned-ci-cd-tutorial-sample-app/actions/workflows/docker_build_push.yml/badge.svg)](https://github.com/kboretska/peex-cloned-ci-cd-tutorial-sample-app/actions/workflows/docker_build_push.yml)
[![Release deploy](https://github.com/kboretska/peex-cloned-ci-cd-tutorial-sample-app/actions/workflows/release_deploy.yml/badge.svg)](https://github.com/kboretska/peex-cloned-ci-cd-tutorial-sample-app/actions/workflows/release_deploy.yml)

**NOTE:** This code was written for an
[article](https://medium.com/rockedscience/docker-ci-cd-pipeline-with-github-actions-6d4cd1731030)
in the **RockedScience** publication on Medium.

## Description

This sample Python REST API application was written for a tutorial on implementing Continuous Integration and Delivery pipelines.

It demonstrates how to:

 * Write a basic REST API using the [Flask](http://flask.pocoo.org) microframework
 * Basic database operations and migrations using the Flask wrappers around [Alembic](https://bitbucket.org/zzzeek/alembic) and [SQLAlchemy](https://www.sqlalchemy.org)
 * Write automated unit tests with [unittest](https://docs.python.org/2/library/unittest.html)

Also:

 * How to use [GitHub Actions](https://github.com/features/actions)

## CI/CD feedback loop (badges, GitHub notifications, and email)

### Status badges

The badges at the top of this README link to GitHub Actions and **update automatically** after each run (passing / failing / pending). They refer to workflow **files** (`docker_build_push.yml`, `release_deploy.yml`), not the human-readable workflow titles.

- **Green** — last run of that workflow succeeded.
- **Red** — last run failed.
- **Yellow / pending** — a run is in progress (or GitHub is still refreshing the badge).

If you fork this repo, edit the badge URLs above: `github.com/<owner>/<repo>/actions/workflows/<file>/badge.svg`.

### GitHub notifications and email (no extra secrets in the repo)

This project relies on **GitHub’s built-in** notifications for workflow runs. You do **not** need Slack/Teams webhooks or SMTP secrets in the repository.

**Who gets notified:** typically the user who **triggered** the workflow (for example the author of the push) and people **watching** the repository, depending on [notification settings](https://docs.github.com/en/account-and-profile/managing-subscriptions-and-notifications-on-github/setting-up-notifications/configuring-notifications).

**Email**

1. Use a **verified** email on your GitHub account: **Settings (profile) → Emails**.
2. Open **Settings → Notifications** ([direct link](https://github.com/settings/notifications)).
3. Under **Actions**, choose how you want to be notified (for example **Send notifications for failed workflows only** to reduce noise, or include successes if you need them for coursework).
4. Ensure **Email** is enabled for the notification types you care about (participating, watching, etc.).

**In-app (bell) and mobile**

- The **Notifications** inbox on GitHub shows workflow-related items when you participate or watch the repo.
- Install the **GitHub mobile app** and enable push notifications if you want alerts on your phone.

**Watching this repository**

- On the repo page, use **Watch → Participating** or **All Activity** to control how many events create notifications. For a small project, **Participating** plus Actions email for failures is usually enough.

**What you get:** GitHub sends **concise** emails or web notifications with a link to the workflow run (logs, branch, commit). **Secrets are never included** in those messages.

**CI vs CD in terms of notifications:** any failed job in **CI — test and push…** or **Release - deploy…** can trigger a failure notification to subscribers, depending on your settings. Successful runs can be muted via “failed only” for Actions.

**Coursework / evidence:** screenshot your **Notification settings** (Actions section), a **badge** in passing and failing states, and an **email** or **GitHub Notifications** inbox entry after a failed run (temporarily break a test, then revert).

## Requirements

 * `Python 3.8` (recommended for local runs; **3.12+** may fail with the pinned **Werkzeug 1.x** stack required by Flask 1.1.x — CI uses 3.8)
 * `Pip`
 * `virtualenv`, or `conda`, or `miniconda`

The `psycopg2` package does require `libpq-dev` and `gcc`.
To install them (with `apt`), run:

```sh
$ sudo apt-get install libpq-dev gcc
```

## Installation

With `virtualenv`:

```sh
$ python -m venv venv
$ source venv/bin/activate
$ pip install -r requirements.txt
```

With `conda` or `miniconda`:

```sh
$ conda env create -n ci-cd-tutorial-sample-app python=3.8
$ source activate ci-cd-tutorial-sample-app
$ pip install -r requirements.txt
```

Optional: set the `DATABASE_URL` environment variable to a valid SQLAlchemy connection string. Otherwise, a local SQLite database will be created.

Initalize and seed the database:

```sh
$ flask db upgrade
$ python seed.py
```

## Running tests

Run:

```sh
$ python -m unittest discover
```

## Running the application

### Running locally

Run the application using the built-in Flask server:

```sh
$ flask run
```

### Running on a production server

Run the application using `gunicorn`:

```sh
$ pip install -r requirements-server.txt
$ gunicorn app:app
```

To set the listening address and port, run:

```
$ gunicorn app:app -b 0.0.0.0:8000
```

## Versioning, container registry, and releases

This repository implements **automated artifact versioning** in GitHub Actions: every push to `master` or `main` (and every matching semantic tag push) produces an image in **GitHub Container Registry (GHCR)** with multiple **immutable** tags.

### Versioning scheme

- **Semantic versioning (SemVer)** for releases: create an annotated or lightweight Git tag `vMAJOR.MINOR.PATCH` (for example `v1.2.0`). The CI pipeline tags the image with `1.2.0`, `1.2`, and the other tags below. Tags follow [Semantic Versioning 2.0.0](https://semver.org/).
- **Build number**: each workflow run adds tag `build-<GITHUB_RUN_NUMBER>`. This number is unique and monotonic for the repository; it is **never reused**.
- **Commit identity**: tag `sha-<short>` ties the image to the exact Git revision (short SHA). **Not overwritten** once pushed.
- **`latest`**: moving pointer, updated only on pushes to the **default branch** (`master` or `main`). Use pinned tags (`build-*`, `sha-*`, or SemVer) for production rollouts.

Version information is baked into the image as `APP_VERSION` (build number) and `GIT_COMMIT_SHORT`, and exposed at runtime via `GET /version` for logs and traceability.

### How versions are generated

1. Workflow [.github/workflows/docker_build_push.yml](.github/workflows/docker_build_push.yml) runs tests, then uses [docker/metadata-action](https://github.com/docker/metadata-action) to compute OCI tags and labels from the Git ref and SemVer rules.
2. [docker/build-push-action](https://github.com/docker/build-push-action) builds the `Dockerfile` and pushes to `ghcr.io/<owner>/<repo>` (name lowercased). `GITHUB_TOKEN` is used (`packages: write`).
3. Pipeline logs print the image name, tag list, `BUILD_VERSION`, and full Git SHA (see step **Log published tags**).

**First-time SemVer example** (after a successful CI push):

```sh
git tag v0.1.0
git push origin v0.1.0
```

Optional: integrate [semantic-release](https://semantic-release.gitbook.io/) or [Conventional Commits](https://www.conventionalcommits.org/) in a separate job if you want changelog-driven bumps; this sample uses explicit Git tags plus build numbers.

### Deploy a specific version (release pipeline)

Use the **Release - deploy by image version** workflow ([.github/workflows/release_deploy.yml](.github/workflows/release_deploy.yml)):

1. In GitHub: **Actions** → **Release — deploy by image version** → **Run workflow**.
2. Set **image_version** to an immutable tag from GHCR (for example `build-42`, `sha-a1b2c3d`, or `1.2.0`).
3. Optionally set **deployment_label** (for example `production` or `rollback`).

The job pulls the image from GHCR (no rebuild), runs a short smoke test, and prints `/version` in the logs. For a real environment, replace the smoke step with your target (Kubernetes `kubectl set image`, ECS task definition, VM pull/run, etc.) while keeping the same **pin by tag** rule.

### Rollback

Rollback is **deploying a previous immutable tag** again:

1. In GHCR, open the package → **Versions** and pick an older tag (for example the previous `build-*` or `sha-*`).
2. Run **Release — deploy by image version** with that tag as **image_version** and label e.g. `rollback-to-build-41`.

No reprocessing of source is required; the artifact already exists in the registry.

### Traceability and immutability

- **Immutable**: `build-*`, `sha-*`, and SemVer tags are not overwritten by this pipeline. Do not force-push tags that already released.
- **Traceability**: Image labels include `org.opencontainers.image.revision` and `ci.build-version`. Deployment logs show the pulled tag and JSON from `GET /version`.

### Artifact retention

Configure **retention for GitHub Packages** in your org/user settings so old package versions are pruned on a schedule while recent releases remain available. See [GitHub Docs: Configuring package retention policies](https://docs.github.com/packages/learn-github-packages/deleting-a-package).

### Evidence for coursework / reports

Capture: GHCR UI showing multiple tags; CI run logs showing version/tag generation; release workflow run deploying a chosen tag; a second run using an older tag as rollback; Git tags in the repository if you use SemVer.

---

## Running on Docker

### Local build

Run:

```
$ docker build -t ci-cd-tutorial-sample-app:latest .
$ docker run -d -p 8000:8000 ci-cd-tutorial-sample-app:latest
```

With version args (as in CI):

```
$ docker build \
  --build-arg APP_VERSION=local-dev \
  --build-arg GIT_COMMIT_SHORT=manual \
  -t ci-cd-tutorial-sample-app:local .
$ curl -s http://127.0.0.1:8000/version
```

### Pull from GHCR (after CI)

Replace `OWNER` and `REPO` with your GitHub owner and repository name (lowercase):

```
$ docker pull ghcr.io/OWNER/REPO:latest
$ docker run -d -p 8000:8000 ghcr.io/OWNER/REPO:build-<N>
```

## Deploying to Heroku

Run:

```sh
$ heroku create
$ git push heroku master
$ heroku run flask db upgrade
$ heroku run python seed.py
$ heroku open
```

or use the automated deploy feature:

[![Deploy](https://www.herokucdn.com/deploy/button.svg)](https://heroku.com/deploy)

For more information about using Python on Heroku, see these Dev Center articles:

 - [Python on Heroku](https://devcenter.heroku.com/categories/python)
