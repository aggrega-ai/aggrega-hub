# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Cognitio S.r.l.
#
# The quickstart chat page: one static binary on an empty image, the page and
# its images embedded in it.
#
# The Go toolchain image is pinned by the digest of its multi-platform index,
# so every build starts from the same bytes. The program uses the Go standard
# library alone, so there is no module to download. The binary is compiled on
# the build machine's own platform for the target platform, so an image for
# another processor needs no emulation. It is built without the build machine's
# paths, version-control stamp or build ID, so the same sources give the same
# binary.
#
# BUILDPLATFORM, TARGETOS and TARGETARCH are the platform arguments BuildKit
# sets by itself; a builder that does not set them is given them with
# --build-arg, as the README shows.
ARG BUILDPLATFORM
FROM --platform=$BUILDPLATFORM golang:1.26-alpine@sha256:a2012b4a1d1f9f7e9f44e0d39b805a901e856b1dd80b4e6ee4338db547050308 AS build
ARG TARGETOS
ARG TARGETARCH
WORKDIR /src
COPY go.mod main.go ./
COPY page ./page
RUN CGO_ENABLED=0 GOOS=$TARGETOS GOARCH=$TARGETARCH \
    go build -trimpath -buildvcs=false -ldflags='-s -w -buildid=' -o /out/quickstart-chat .

FROM scratch
LABEL org.opencontainers.image.title="quickstart-chat" \
      org.opencontainers.image.description="A small chat page for the quickstart agent, forwarding each message to the agent's own HTTP API." \
      org.opencontainers.image.licenses="Apache-2.0" \
      org.opencontainers.image.source="https://github.com/aggrega-ai/aggrega-hub"
COPY --from=build /out/quickstart-chat /quickstart-chat
USER 65532:65532
EXPOSE 8090
ENTRYPOINT ["/quickstart-chat"]
