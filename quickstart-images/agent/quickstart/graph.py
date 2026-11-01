# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Cognitio S.r.l.
"""The agent's graph: one node that answers the conversation so far.

Everything it connects to comes from the environment, under the names the
catalog's Compose realization of the LangGraph agent delivers:

  OPENAI_BASE_URL              the OpenAI-compatible endpoint the model answers at
  OPENAI_MODEL                 the model asked for at that endpoint
  OPENAI_API_KEY               the key sent to the endpoint, where it needs one
  LANGGRAPH_CHECKPOINTER_HOST  the Valkey or Redis server keeping conversations
  LANGGRAPH_CHECKPOINTER_PORT  that server's port

`app` is the compiled graph. Invoke it with a thread ID in the configuration,
`{"configurable": {"thread_id": "..."}}`; every turn on one thread ID continues
the same conversation, whichever process serves it.
"""

from __future__ import annotations

import os

import redis
from langchain_core.messages import AIMessage, BaseMessage
from langgraph.graph import END, START, MessagesState, StateGraph
from openai import OpenAI

from quickstart.checkpoint import ValkeySaver

SYSTEM_PROMPT = "You are a helpful assistant in a short demonstration. Answer in one or two sentences."

_ROLES = {"human": "user", "ai": "assistant", "system": "system"}


def _required(name: str) -> str:
    value = os.environ.get(name, "")
    if not value:
        raise RuntimeError(f"{name} is not set: the agent reads it from its environment")
    return value


MODEL = _required("OPENAI_MODEL")

# An endpoint that needs no key, as a local model server does, still receives
# one, because the client sends a key on every request.
client = OpenAI(
    base_url=_required("OPENAI_BASE_URL"),
    api_key=os.environ.get("OPENAI_API_KEY") or "unused",
    timeout=300,
    max_retries=2,
)

store = redis.Redis(
    host=_required("LANGGRAPH_CHECKPOINTER_HOST"),
    port=int(_required("LANGGRAPH_CHECKPOINTER_PORT")),
    socket_connect_timeout=5,
)


def _as_openai(message: BaseMessage) -> dict[str, str]:
    return {"role": _ROLES.get(message.type, "user"), "content": str(message.content)}


def answer(state: MessagesState) -> dict[str, list[AIMessage]]:
    reply = client.chat.completions.create(
        model=MODEL,
        messages=[{"role": "system", "content": SYSTEM_PROMPT}] + [_as_openai(m) for m in state["messages"]],
        temperature=0,
        max_tokens=200,
    )
    return {
        "messages": [
            AIMessage(content=reply.choices[0].message.content or "", response_metadata={"model": reply.model})
        ]
    }


builder = StateGraph(MessagesState)
builder.add_node("answer", answer)
builder.add_edge(START, "answer")
builder.add_edge("answer", END)

checkpointer = ValkeySaver(store)
app = builder.compile(checkpointer=checkpointer)
