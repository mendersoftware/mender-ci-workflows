ARG MENDER_CLI_VERSION=1.11.0
ARG MENDER_ARTIFACT_VERSION=3.10.1
ARG MENDER_CLIENT_VERSION=3.5.1
ARG MENDER_APP_UPDATE_MODULE_VERSION=master

FROM golang:1.22 as cli-builder
WORKDIR /go/src/github.com/mendersoftware/mender-cli
ARG MENDER_CLI_VERSION
RUN git clone https://github.com/mendersoftware/mender-cli.git . && \
    git checkout $MENDER_CLI_VERSION && \
    make get-build-deps && \
    make build

FROM golang:1.22 as artifact-builder
WORKDIR /go/src/github.com/mendersoftware/mender-artifact
ARG MENDER_ARTIFACT_VERSION
RUN git clone https://github.com/mendersoftware/mender-artifact.git . && \
    git checkout $MENDER_ARTIFACT_VERSION && \
    make get-build-deps || ( \
        apt-get update -qq && \
        apt-get install -yyq $(cat deb-requirements.txt) ) && \
    make build

FROM golang:1.22 as client-builder
WORKDIR /go/src/github.com/mendersoftware/mender
ARG MENDER_CLIENT_VERSION
RUN git clone https://github.com/mendersoftware/mender.git . && \
    git checkout $MENDER_CLIENT_VERSION && \
    DESTDIR=/install-modules-gen make install-modules-gen

FROM docker:26-cli
ARG MENDER_APP_UPDATE_MODULE_VERSION
COPY --from=cli-builder /go/src/github.com/mendersoftware/mender-cli /usr/bin/
COPY --from=artifact-builder /go/src/github.com/mendersoftware/mender-artifact/mender-artifact /usr/bin/
COPY --from=client-builder /install-modules-gen/usr/bin/ /usr/bin/
# The --mount instead of COPY is used to decrease the image layer size. Requires: 'export DOCKER_BUILDKIT=1'
RUN wget https://raw.githubusercontent.com/mendersoftware/app-update-module/$MENDER_APP_UPDATE_MODULE_VERSION/gen/app-gen -O /usr/bin/app-gen && chmod +x /usr/bin/app-gen
RUN --mount=type=bind,source=apk-requirements.txt,target=/apk-requirements.txt \
    apk add --no-cache $(cat apk-requirements.txt)
