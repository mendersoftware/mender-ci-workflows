ARG MENDER_CLI_VERSION=v2.0.0
ARG MENDER_ARTIFACT_VERSION=4.4.1
ARG MENDER_CLIENT_VERSION=5.1.0
ARG MENDER_APP_UPDATE_MODULE_VERSION=master

FROM golang:1.26 as cli-builder
WORKDIR /go/src/github.com/mendersoftware/mender-cli
ARG MENDER_CLI_VERSION
RUN git clone https://github.com/mendersoftware/mender-cli.git . && \
    git checkout $MENDER_CLI_VERSION && \
    make get-build-deps && \
    make build

FROM golang:1.26 as artifact-builder
WORKDIR /go/src/github.com/mendersoftware/mender-artifact
ARG MENDER_ARTIFACT_VERSION
RUN git clone https://github.com/mendersoftware/mender-artifact.git . && \
    git checkout $MENDER_ARTIFACT_VERSION && \
    make get-build-deps || ( \
        apt-get update -qq && \
        apt-get install -yyq $(cat deb-requirements.txt) ) && \
    make build

FROM debian:13 as client-builder
ARG MENDER_CLIENT_VERSION
WORKDIR /tmp
RUN apt update && apt install -y build-essential curl unzip cmake
RUN curl -Lo $MENDER_CLIENT_VERSION.zip https://github.com/mendersoftware/mender/archive/${MENDER_CLIENT_VERSION}.zip; \
    unzip $MENDER_CLIENT_VERSION.zip; \
    cmake -S /tmp/mender-$MENDER_CLIENT_VERSION -B /build -DCMAKE_INSTALL_PREFIX=/install-modules-gen -D MENDER_NO_BUILD=1; \
    make -C /build install-modules-gen;

FROM debian:13.6-slim
COPY --from=cli-builder /go/src/github.com/mendersoftware/mender-cli /usr/bin/
COPY --from=artifact-builder /go/src/github.com/mendersoftware/mender-artifact/mender-artifact /usr/bin/
COPY --from=client-builder /install-modules-gen/bin/ /usr/bin/

# Bring in libssl for mender-artifact signing to work
RUN apt-get update && apt-get install libssl3 ca-certificates curl -y && apt-get clean
