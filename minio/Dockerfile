ARG BUILD_FROM=hassioaddons/base:8.0.6
FROM golang:1.15-alpine as builder

ARG MINIO_VERSION=master
ARG MC_VERSION=master
LABEL maintainer="MinIO Inc <dev@min.io>"

ENV GOPATH /go
ENV CGO_ENABLED 0
ENV GO111MODULE on


RUN  apk add --no-cache git \
     && git config --global advice.detachedHead false
RUN  git clone --depth 1 --branch ${MINIO_VERSION} https://github.com/minio/minio \
     && cd minio \
     && go install -v -ldflags "$(MINIO_RELEASE="RELEASE" go run buildscripts/gen-ldflags.go $(git describe --tags --abbrev=0 | sed 's/^RELEASE\.//'))" \
     && cd ..

COPY mc.patch /tmp
RUN  git clone --depth 1 --branch ${MC_VERSION} https://github.com/minio/mc.git \
     && cd mc \
     && git apply /tmp/mc.patch \
     && go install -v -ldflags "$(MC_RELEASE="RELEASE" go run buildscripts/gen-ldflags.go $(git describe --tags --abbrev=0 | sed 's/^RELEASE\.//'))" \
     && cd ..

# hadolint ignore=DL3006
FROM ${BUILD_FROM}

# Set shell
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

ENV MINIO_UPDATE_MINISIGN_PUBKEY="RWTx5Zr1tiHQLwG9keckT0c45M3AGeHD6IvimQHpyRywVWGbP1aVSGav"

EXPOSE 9000

COPY --from=builder /go/bin/minio /usr/bin/minio
COPY --from=builder /go/bin/mc /usr/bin/mc
COPY --from=builder /go/minio/CREDITS /licenses/minio/CREDITS
COPY --from=builder /go/minio/LICENSE /licenses/minio/LICENSE
COPY --from=builder /go/mc/CREDITS /licenses/mc/CREDITS
COPY --from=builder /go/mc/LICENSE /licenses/mc/LICENSE

RUN apk add --no-cache \
    dropbear
RUN apk add --no-cache \
    -X http://dl-cdn.alpinelinux.org/alpine/edge/testing \
    rlwrap

# Copy root filesystem
COPY rootfs /

# Build arguments
ARG BUILD_ARCH
ARG BUILD_DATE
ARG BUILD_REF
ARG BUILD_VERSION

# Labels
LABEL \
    io.hass.name="MinIO" \
    io.hass.description="S3 compatible onject store" \
    io.hass.arch="${BUILD_ARCH}" \
    io.hass.type="addon" \
    io.hass.version=${BUILD_VERSION} \
    maintainer="Morten <221842+buhl@users.noreply.github.com>" \
    org.opencontainers.image.title="MinIO" \
    org.opencontainers.image.description="S3 compatible onject store" \
    org.opencontainers.image.vendor="Home Assistant Community Add-ons" \
    org.opencontainers.image.authors="Morten <221842+buhl@users.noreply.github.com>" \
    org.opencontainers.image.licenses="addon: MIT, minio+mc:Apache2.0" \
    org.opencontainers.image.url="https://addons.community" \
    org.opencontainers.image.source="https://github.com/buhl/HAOS-addon-minio" \
    org.opencontainers.image.documentation="https://github.com/buhl/HAOS-addon-minio/blob/master/README.md.j2" \
    org.opencontainers.image.created=${BUILD_DATE} \
    org.opencontainers.image.revision=${BUILD_REF} \
    org.opencontainers.image.version=${BUILD_VERSION}
