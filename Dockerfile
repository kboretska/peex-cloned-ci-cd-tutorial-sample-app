# Supported base image (avoid EOL Ubuntu releases; reduces OS-level CVE noise in scans).
FROM python:3.8-slim-bookworm

ARG APP_VERSION=unknown
ARG APP_SEMVER=unknown
ARG GIT_COMMIT_SHORT=unknown
ARG CI_RUN_NUMBER=unknown
ENV APP_VERSION=${APP_VERSION}
ENV APP_SEMVER=${APP_SEMVER}
ENV GIT_COMMIT_SHORT=${GIT_COMMIT_SHORT}
ENV CI_RUN_NUMBER=${CI_RUN_NUMBER}

# Upgrade OS packages so Trivy sees patched Debian security versions (e.g. libsqlite3).
RUN apt-get update && \
    DEBIAN_FRONTEND=noninteractive apt-get upgrade -y && \
    apt-get install -y --no-install-recommends libpq-dev gcc \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /sample-app

COPY . /sample-app/

RUN pip install --no-cache-dir -r requirements.txt && \
    pip install --no-cache-dir -r requirements-server.txt

ENV LC_ALL="C.UTF-8"
ENV LANG="C.UTF-8"

EXPOSE 8000/tcp

CMD ["/bin/sh", "-c", "flask db upgrade && gunicorn app:app -b 0.0.0.0:8000"]
