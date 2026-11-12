# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Cognitio S.r.l.
#
# The quickstart web app: one static binary on an empty image, its page and
# the page's images embedded in it.
#
# The Go toolchain image is pinned by the digest of its multi-platform index,
# so every build starts from the same bytes, and the module graph is pinned by
# go.sum, which the build verifies. The binary is compiled on the build
# machine's own platform for the target platform, so an image for another
# processor needs no emulation. It is built without the build machine's paths,
# version-control stamp or build ID, so the same sources give the same binary.
#
# BUILDPLATFORM, TARGETOS and TARGETARCH are the platform arguments BuildKit
# sets by itself; a builder that does not set them is given them with
# --build-arg, as the README shows.
ARG BUILDPLATFORM
FROM --platform=$BUILDPLATFORM golang:1.26-alpine@sha256:a2012b4a1d1f9f7e9f44e0d39b805a901e856b1dd80b4e6ee4338db547050308 AS build
ARG TARGETOS
ARG TARGETARCH
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download && go mod verify
COPY main.go ./
COPY page ./page
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -buildvcs=false -ldflags='-s -w -buildid=' -o /out/quickstart-web .

FROM scratch
LABEL org.opencontainers.image.title="quickstart-web" \
      org.opencontainers.image.description="A small web app keeping notes in PostgreSQL and answering them from a Redis cache when one is wired, with a page for the browser." \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.source="https://github.com/aggrega-ai/aggrega-hub"
COPY --from=build /out/quickstart-web /quickstart-web
USER 65532:65532
EXPOSE 8080
ENTRYPOINT ["/quickstart-web"]
