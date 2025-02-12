ARG MENDER_CLI_VERSION=1.11.0
ARG MENDER_ARTIFACT_VERSION=3.10.1
ARG MENDER_CLIENT_VERSION=3.5.1
ARG MENDER_APP_UPDATE_MODULE_VERSION=master

FROM golang:1.23 as cli-builder
WORKDIR /go/src/github.com/mendersoftware/mender-cli
ARG MENDER_CLI_VERSION
RUN git clone https://github.com/mendersoftware/mender-cli.git . && \
    git checkout $MENDER_CLI_VERSION && \
    make get-build-deps && \
    make build

FROM golang:1.23 as artifact-builder
WORKDIR /go/src/github.com/mendersoftware/mender-artifact
ARG MENDER_ARTIFACT_VERSION
RUN git clone https://github.com/mendersoftware/mender-artifact.git . && \
    git checkout $MENDER_ARTIFACT_VERSION && \
    make get-build-deps || ( \
        apt-get update -qq && \
        apt-get install -yyq $(cat deb-requirements.txt) ) && \
    make build

FROM golang:1.23 as client-builder
WORKDIR /go/src/github.com/mendersoftware/mender
ARG MENDER_CLIENT_VERSION
RUN git clone https://github.com/mendersoftware/mender.git . && \
    git checkout $MENDER_CLIENT_VERSION && \
    DESTDIR=/install-modules-gen make install-modules-gen

FROM debian:12.8-slim
COPY --from=cli-builder /go/src/github.com/mendersoftware/mender-cli /usr/bin/
COPY --from=artifact-builder /go/src/github.com/mendersoftware/mender-artifact/mender-artifact /usr/bin/
COPY --from=client-builder /install-modules-gen/usr/bin/ /usr/bin/

# Bring in libssl for mender-artifact signing to work
RUN apt-get update && apt-get install libssl3 ca-certificates -y && apt-get clean
