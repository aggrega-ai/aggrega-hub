<!--
SPDX-License-Identifier: Apache-2.0
Copyright 2026 Cognitio s.r.l.
-->

# quickstart-web

A small web application for the quickstarts: it keeps short notes in PostgreSQL and, when a Redis cache is wired to
it, answers a note it has already read from the cache. Every answer about a note says where it came from, in its
`source` field, so the cache is visible from outside.

Opened in a browser, it shows a small page: add a note, see the notes listed, and read one to see whether that read
came from PostgreSQL or from the cache — or, with no cache wired, that every read comes from PostgreSQL. The page
loads nothing from anywhere but this server — no script, stylesheet, font or image from elsewhere, and no analytics —
and its content security policy tells the browser to refuse anything else.

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

Open `http://localhost:8080/` in a browser for the page. `GET /` answers the page only to a request whose `Accept`
header names `text/html` with a higher preference than JSON, as a browser's does; any other request — curl's default
`*/*`, or one asking for `application/json` — gets the JSON below, and both answers carry `Vary: Accept`. The page
sends the same requests as the lines below.

| Request | Does |
|---|---|
| `GET /` | what the application is connected to, as JSON; to a browser, the page |
| `POST /notes` | stores the request body as a new note |
| `GET /notes/<id>` | one note, from the cache when it holds it; its `source` says which |
| `GET /notes` | the 50 most recent notes, newest first, as `{"notes": [...]}`, read from PostgreSQL; it neither reads nor fills the cache |
| `GET /page/<file>` | the page's script, stylesheets and images |
| `GET /healthz` | whether PostgreSQL answers |

```sh
# What the application is connected to.
curl -s http://localhost:8080/

# Store a note. The request body is the note.
curl -s -X POST --data 'hello from the quickstart' http://localhost:8080/notes

# Read it twice: the first answer says "source": "postgresql", the second "source": "cache".
curl -s http://localhost:8080/notes/1
curl -s http://localhost:8080/notes/1

# The most recent notes.
curl -s http://localhost:8080/notes

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
| `page/index.html`, `page/notes.js`, `page/notes.css` | the page, embedded in the binary | Apache-2.0 |
| `page/tokens.css` | the brand's colours, spacing, radii and type scale as CSS custom properties, which `notes.css` reads, embedded in the binary | Apache-2.0 |
| `page/wordmark-light.svg`, `page/favicon.ico` | the Aggrega logo for a light ground and the browser-tab icon, embedded in the binary | Apache-2.0 |

`tokens.css`, `wordmark-light.svg` and `favicon.ico` are copied unchanged from the Aggrega brand package,
`@aggrega-ai/brand`, repository `aggrega-ai/aggrega-brand` at commit `20a1a083c18d51b3c700e936e39f0d53bd305e8e`:

| Copy | From | sha256 |
|---|---|---|
| `page/tokens.css` | `dist/tokens.css` | `4cb1ab92de7c3fec8fd69659d9f265a1f034dbe614cbcc43cf1b7ef2ea05286b` |
| `page/wordmark-light.svg` | `logo/wordmark-light.svg` | `efc71dae913cda1169f80d884f2c598323d42aff7271697d75f635d05fef175f` |
| `page/favicon.ico` | `logo/favicon.ico` | `4ea9f05a458537ab621b8ac4e63e329d70b55dbb4a77e6bf437ebb12a314ff71` |

They are the same three files the `quickstart-chat` image beside this one carries. Each image is built from its own
directory alone, so each keeps its own copy rather than sharing one; to take a newer brand, copy the three files again
from the commit to ship into both images, and update this table, the other image's and both `VERSION` files.

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
