FROM ubuntu:18.04

ARG APP_VERSION=unknown
ARG APP_SEMVER=unknown
ARG GIT_COMMIT_SHORT=unknown
ARG CI_RUN_NUMBER=unknown
ENV APP_VERSION=${APP_VERSION}
ENV APP_SEMVER=${APP_SEMVER}
ENV GIT_COMMIT_SHORT=${GIT_COMMIT_SHORT}
ENV CI_RUN_NUMBER=${CI_RUN_NUMBER}

RUN apt-get update && \
    apt-get -y upgrade && \
    DEBIAN_FRONTEND=noninteractive apt-get install -yq libpq-dev gcc python3.8 python3-pip && \
    apt-get clean

WORKDIR /sample-app

COPY . /sample-app/

RUN pip3 install -r requirements.txt && \
    pip3 install -r requirements-server.txt

ENV LC_ALL="C.UTF-8"
ENV LANG="C.UTF-8"

EXPOSE 8000/tcp

CMD ["/bin/sh", "-c", "flask db upgrade && gunicorn app:app -b 0.0.0.0:8000"]
