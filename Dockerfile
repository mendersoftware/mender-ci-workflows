ARG MENDER_CLI_VERSION=1.9.0
ARG MENDER_ARTIFACT_VERSION=3.9.0
ARG MENDER_CLIENT_VERSION=3.4.0

FROM golang:1.20 as cli-builder
WORKDIR /go/src/github.com/mendersoftware/mender-cli
ARG MENDER_CLI_VERSION
RUN git clone https://github.com/mendersoftware/mender-cli.git . && \
    git checkout $MENDER_CLI_VERSION && \
    make get-deps && \
    make build

FROM golang:1.20 as artifact-builder
WORKDIR /go/src/github.com/mendersoftware/mender-artifact
ARG MENDER_ARTIFACT_VERSION
RUN git clone https://github.com/mendersoftware/mender-artifact.git . && \
    git checkout $MENDER_ARTIFACT_VERSION && \
    make get-build-deps || ( \
        apt-get update -qq && \
        apt-get install -yyq $(cat deb-requirements.txt) ) && \
    make build

FROM golang:1.20 as client-builder
WORKDIR /go/src/github.com/mendersoftware/mender
ARG MENDER_CLIENT_VERSION
RUN git clone https://github.com/mendersoftware/mender.git . && \
    git checkout $MENDER_CLIENT_VERSION && \
    DESTDIR=/install-modules-gen make install-modules-gen

FROM debian:12.0-slim
COPY --from=cli-builder /go/src/github.com/mendersoftware/mender-cli /usr/bin/
COPY --from=artifact-builder /go/src/github.com/mendersoftware/mender-artifact/mender-artifact /usr/bin/
COPY --from=client-builder /install-modules-gen/usr/bin/ /usr/bin/
# The --mount instead of COPY is used to decrease the image layer size. Requires: 'export DOCKER_BUILDKIT=1'
RUN --mount=type=bind,source=deb-requirements.txt,target=/deb-requirements.txt \
    apt-get update && \
    apt-get install -y $(cat deb-requirements.txt) && \
    rm -rf /var/lib/apt/lists/*
