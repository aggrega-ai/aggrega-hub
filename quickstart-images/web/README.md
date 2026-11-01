<!--
SPDX-License-Identifier: Apache-2.0
Copyright 2026 Cognitio S.r.l.
-->

# quickstart-web

A small web application for the quickstarts: it keeps short notes in PostgreSQL and, when a Redis cache is wired to
it, answers a note it has already read from the cache. Every answer about a note says where it came from, in its
`source` field, so the cache is visible from outside.

It is published as `hub.aggrega.ai/tools/quickstart-web:<version>`, for Linux on x86-64 (`linux/amd64`) and on ARM
(`linux/arm64`), under the Apache-2.0 licence. The version is the one line of `VERSION`.

## Configuration

The application reads its environment and nothing else. In an Aggregate it runs as a `core/compute/server`
component, and each of its connections dictates these names in its `inject:` block:

| Variable | Read as |
|---|---|
| `PGHOST`, `PGPORT`, `PGUSER`, `PGPASSWORD`, `PGDATABASE` | the PostgreSQL server, the names the PostgreSQL client libraries read by convention |
| `REDIS_HOST`, `REDIS_PORT` | the Redis cache; with `REDIS_HOST` unset the application runs without one, and `REDIS_PORT` defaults to 6379 |

It listens on port 8080. It creates its one table, `notes`, the first time it needs it, so the database may still be
starting when the application does.

## Requests

```sh
# What the application is connected to.
curl -s http://localhost:8080/

# Store a note. The request body is the note.
curl -s -X POST --data 'hello from the quickstart' http://localhost:8080/notes

# Read it twice: the first answer says "source": "postgresql", the second "source": "cache".
curl -s http://localhost:8080/notes/1
curl -s http://localhost:8080/notes/1

# Whether PostgreSQL answers.
curl -s http://localhost:8080/healthz
```

A cached note is kept for five minutes. When the cache cannot be reached, the note is read from PostgreSQL and the
application's log says so.

## The image

| Part | What it is | Licence, as its publisher declares it |
|---|---|---|
| Build stage | `golang:1.26-alpine`, the Docker Official Image for Go, pinned by the digest of its multi-platform index | Go: BSD-3-Clause |
| Runtime | `scratch`, the empty image: the image holds the one static binary and nothing else | — |
| `github.com/jackc/pgx/v5` and its modules `pgpassfile`, `pgservicefile`, `puddle/v2` | the PostgreSQL driver | MIT |
| `github.com/redis/go-redis/v9` | the Redis client | BSD-2-Clause |
| `github.com/cespare/xxhash/v2`, `go.uber.org/atomic` | used by the two clients | MIT |
| `golang.org/x/sync`, `golang.org/x/sys`, `golang.org/x/text` | used by the two clients | BSD-3-Clause |

Every module version is pinned by `go.sum`, which the build verifies. The binary is compiled without the build
machine's paths, version-control stamp or build ID, and runs as an unprivileged user.

## Building

With BuildKit, for both platforms:

```sh
docker buildx build --platform linux/amd64,linux/arm64 .
```

A builder that does not set the platform arguments by itself is given them:

```sh
docker build --build-arg BUILDPLATFORM=linux/amd64 --build-arg TARGETOS=linux --build-arg TARGETARCH=amd64 \
  -t quickstart-web .
```

A change to anything the image is built from — every file here but this README — is published under a new version:
raise `VERSION` in the same commit. The publish workflow stops a run whose last change to these sources left
`VERSION` alone.
