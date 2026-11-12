<!--
SPDX-License-Identifier: Apache-2.0
Copyright 2026 Cognitio S.r.l.
-->

# quickstart-chat

A small chat page for the quickstart agent. It serves one page in the browser and forwards each message the page sends
to the agent's own HTTP API, so you chat with the agent, and the agent with its model. It keeps nothing itself: each
conversation lives in the agent, which keeps it in its store, and the page remembers only the conversation's name, so a
reload continues where you stopped. Each reply shows the model the agent says answered it.

The page loads nothing from anywhere but this server — no script, stylesheet, font or image from elsewhere, and no
analytics — and its content security policy tells the browser to refuse anything else.

It is published as `hub.aggrega.ai/tools/quickstart-chat:<version>`, for Linux on x86-64 (`linux/amd64`) and on ARM
(`linux/arm64`), under the Apache-2.0 licence. The version is the one line of `VERSION`.

## Configuration

The server reads its environment and nothing else. In an Aggregate it runs as a `core/compute/server` component, and
its own `inject:` block sets these names:

| Variable | Read as |
|---|---|
| `AGENT_URL` | where the quickstart agent answers; `http://agent:8000` when unset, the address a peer on the same Compose network reaches an agent component named `agent` at |
| `CHAT_SUBTITLE` | the sentence shown under the page's header, naming what answers; when unset, "Answers come from the model behind the quickstart agent." |

It listens on port 8090. A turn waits up to five minutes for the agent, since a small model on a laptop's processor
can take that long over one answer.

## Requests

Open `http://localhost:8090/` in a browser for the page. The page sends the agent's own requests to the server, which
forwards each to the agent and answers with the agent's own reply; when the agent cannot be reached, it answers HTTP
502 with an `error` saying so:

| Request | Does |
|---|---|
| `GET /` | the chat page |
| `GET /page/<file>` | the page's script, stylesheet and images |
| `POST /threads/<thread>/turns` with `{"message": "..."}` | one turn on that conversation, forwarded to the agent |
| `GET /threads/<thread>` | the conversation so far, from the agent |
| `GET /healthz` | the agent's own answer on whether its store answers |

A thread name is 1 to 64 letters, digits, dots, underscores or hyphens; the server refuses any other with HTTP 400
before it reaches the agent. Of a turn's body it forwards only the `message`, re-encoded as JSON, and only while that
is at most 16384 bytes, the most the agent reads of a request body; a longer one is refused with HTTP 413.

```sh
# One turn, then the conversation so far.
curl -s -X POST -H 'Content-Type: application/json' --data '{"message": "What is the capital of France?"}' \
  http://localhost:8090/threads/demo/turns
curl -s http://localhost:8090/threads/demo
```

## The image

| Part | What it is | Licence, as its publisher declares it |
|---|---|---|
| Build stage | `golang:1.26-alpine`, the Docker Official Image for Go, pinned by the digest of its multi-platform index | Go: BSD-3-Clause |
| Runtime | `scratch`, the empty image: the image holds the one static binary and nothing else | — |
| The program | Go's standard library and nothing else, so `go.mod` requires no module | BSD-3-Clause |
| `page/index.html`, `page/chat.js`, `page/chat.css` | the page, embedded in the binary | Apache-2.0 |
| `page/tokens.css` | the brand's colours, spacing, radii and type scale as CSS custom properties, which `chat.css` reads, embedded in the binary | Apache-2.0 |
| `page/wordmark-light.svg`, `page/favicon.ico` | the Aggrega logo for a light ground and the browser-tab icon, embedded in the binary | Apache-2.0 |

`tokens.css`, `wordmark-light.svg` and `favicon.ico` are copied unchanged from the Aggrega brand package, `@aggrega-ai/brand`, repository
`aggrega-ai/aggrega-brand` at commit `20a1a083c18d51b3c700e936e39f0d53bd305e8e`:

| Copy | From | sha256 |
|---|---|---|
| `page/tokens.css` | `dist/tokens.css` | `4cb1ab92de7c3fec8fd69659d9f265a1f034dbe614cbcc43cf1b7ef2ea05286b` |
| `page/wordmark-light.svg` | `logo/wordmark-light.svg` | `efc71dae913cda1169f80d884f2c598323d42aff7271697d75f635d05fef175f` |
| `page/favicon.ico` | `logo/favicon.ico` | `4ea9f05a458537ab621b8ac4e63e329d70b55dbb4a77e6bf437ebb12a314ff71` |

To take a newer brand, copy the three files again from the commit to ship, and update this table and `VERSION`.

The binary is compiled without the build machine's paths, version-control stamp or build ID, and runs as an
unprivileged user.

## Building

With BuildKit, for both platforms:

```sh
docker buildx build --platform linux/amd64,linux/arm64 .
```

A builder that does not set the platform arguments by itself is given them:

```sh
docker build --build-arg BUILDPLATFORM=linux/amd64 --build-arg TARGETOS=linux --build-arg TARGETARCH=amd64 \
  -t quickstart-chat .
```

A change to anything the image is built from — every file here but this README — is published under a new version:
raise `VERSION` in the same commit. The publish workflow stops a run whose last change to these sources left
`VERSION` alone.
