<!--
SPDX-License-Identifier: Apache-2.0
Copyright 2026 Cognitio S.r.l.
-->

# quickstart-agent

A small LangGraph agent for the quickstarts. It answers each turn of a conversation through an OpenAI-compatible
model endpoint — a local Ollama server, or the LiteLLM gateway — and keeps every conversation in a Valkey or Redis
store, so a conversation continues where it stopped after the agent restarts.

It is published as `hub.aggrega.ai/tools/quickstart-agent:<version>`, for Linux on x86-64 (`linux/amd64`) and on
ARM (`linux/arm64`), under the Apache-2.0 licence. The version is the one line of `VERSION`. The catalog's Docker
Compose realization of `core/ai-agent/langgraph` runs it when the Release sets no `infra.image`.

## Configuration

The agent reads its environment and nothing else, under the names that realization delivers from the agent's two
connections:

| Variable | Read as |
|---|---|
| `OPENAI_BASE_URL` | the OpenAI-compatible endpoint, from the `model` connection |
| `OPENAI_MODEL` | the model asked for at that endpoint, from the same connection |
| `OPENAI_API_KEY` | the key sent to the endpoint, from a credential attached on that connection; an endpoint needing no key needs none |
| `LANGGRAPH_CHECKPOINTER_HOST`, `LANGGRAPH_CHECKPOINTER_PORT` | the Valkey or Redis server keeping the conversations, from the `checkpointer_db` connection |

The conversations are stored with plain hashes, sets and sorted sets, so any Valkey or Redis server keeps them; no
server module is needed. Every key starts with `quickstart-agent:`.

## Turns

The agent serves HTTP on port 8000 inside its container, and the image carries `quickstart-ask`, which sends a turn
to it from there. With the stack running under Docker Compose, where `agent` is the component's name in the
Aggregate:

```sh
# A turn on the conversation named demo.
docker compose exec agent quickstart-ask demo "My name is Ada. Please remember it."

# Restart the agent, then continue the same conversation.
docker compose restart agent
docker compose exec agent quickstart-ask demo "What is my name?"

# The conversation as the store holds it.
docker compose exec agent quickstart-ask --history demo
```

Each answer is JSON. `turn` counts the turns of the conversation so far, `messages_before_this_turn` is how many
messages the store held for it when the turn began, and `agent_started_at` is when the serving process started: after
the restart, the second turn reports `"turn": 2` and `"messages_before_this_turn": 2` from a process started later
than the first turn's.

A turn that fails — the model endpoint refuses the request, say — answers HTTP 502 with `{"error": "the turn failed:
<error type>: <error>"}`, and the agent removes the message that turn added, so the conversation is left as it was
before the turn and the next turn on it does not send the failed message again.

Another service on the same network reaches the agent at `http://agent:8000`:

| Request | Does |
|---|---|
| `POST /threads/<thread>/turns` with `{"message": "..."}` | one turn on that conversation |
| `GET /threads/<thread>` | the conversation so far |
| `GET /healthz` | whether the store answers |

A thread name is 1 to 64 letters, digits, dots, underscores or hyphens.

## The image

| Part | What it is | Licence, as its publisher declares it |
|---|---|---|
| Base | `python:3.13-slim`, the Docker Official Image for Python on Debian, pinned by the digest of its multi-platform index | Python: PSF-2.0; Debian packages under their own licences |
| `langgraph`, `langgraph-checkpoint`, `langgraph-prebuilt`, `langgraph-sdk`, `langchain-core`, `langchain-protocol`, `langsmith` | the agent framework | MIT |
| `openai` | the OpenAI-compatible client | Apache-2.0 |
| `redis` | the Valkey and Redis client | MIT |
| the other packages in `requirements.txt` | their dependencies | MIT, BSD-2-Clause, BSD-3-Clause, Apache-2.0 or PSF-2.0, each as its own metadata declares; `certifi` declares MPL-2.0, and `orjson` MPL-2.0 AND (Apache-2.0 OR MIT) |

`requirements.in` names the direct dependencies; `requirements.txt` is compiled from it with every version pinned and
every distribution's hash recorded, and the image installs exactly those files, as prebuilt wheels. The agent runs as
an unprivileged user.

## Building

```sh
docker buildx build --platform linux/amd64,linux/arm64 .
```

or, for the build machine's own platform, `docker build -t quickstart-agent .`.

A change to anything the image is built from — every file here but this README — is published under a new version:
raise `VERSION` in the same commit. The publish workflow stops a run whose last change to these sources left
`VERSION` alone.
