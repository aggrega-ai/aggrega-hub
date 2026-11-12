# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Cognitio S.r.l.
"""The agent's HTTP service, on port 8000.

  POST /threads/<thread>/turns   {"message": "..."}  one turn on that conversation
  GET  /threads/<thread>                             the conversation so far
  GET  /healthz                                      whether the store answers

A turn's answer says how many messages the conversation already held when the
turn began, read back from the store, and when the serving process started, so
a conversation continuing across a restart is visible in the answer itself.

A turn that fails leaves its conversation as it was before the turn: the
message it added is removed again, so a later turn on the same conversation
does not send it to the model a second time.
"""

from __future__ import annotations

import json
import re
import signal
import sys
import threading
import uuid
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from langchain_core.messages import HumanMessage, RemoveMessage

from quickstart.graph import _ROLES, app, store

PORT = 8000
STARTED_AT = datetime.now(timezone.utc).isoformat(timespec="seconds")
THREAD = re.compile(r"^/threads/([A-Za-z0-9._-]{1,64})(/turns)?$")


def _turns(messages) -> int:
    return sum(1 for m in messages if m.type == "human")


def _forget(config: dict, message_id: str) -> None:
    """Remove the message a failed turn added, where the store holds it.

    The store keeps a turn's message before the model is asked, so a turn whose
    answer fails leaves it behind. The removal is recorded as the answer node's
    update, which ends the turn, so the conversation is left with no step
    pending. The answer node writes nothing when it fails, so the turn's own
    message is the only one to remove.
    """
    held = app.get_state(config).values.get("messages", [])
    if any(m.id == message_id for m in held):
        app.update_state(config, {"messages": [RemoveMessage(id=message_id)]}, as_node="answer")


class Handler(BaseHTTPRequestHandler):
    server_version = "quickstart-agent"

    def _reply(self, status: int, body: dict) -> None:
        data = json.dumps(body, indent=2).encode() + b"\n"
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def log_message(self, format: str, *args) -> None:
        sys.stdout.write("%s %s\n" % (self.address_string(), format % args))

    def do_GET(self) -> None:
        if self.path == "/healthz":
            try:
                store.ping()
            except Exception as error:
                self._reply(503, {"status": "the conversation store does not answer", "error": type(error).__name__})
                return
            self._reply(200, {"status": "ok"})
            return
        match = THREAD.match(self.path)
        if not match or match.group(2):
            self._reply(404, {"error": "use POST /threads/<thread>/turns or GET /threads/<thread>"})
            return
        thread = match.group(1)
        state = app.get_state({"configurable": {"thread_id": thread}})
        messages = state.values.get("messages", [])
        self._reply(
            200,
            {
                "thread": thread,
                "turns": _turns(messages),
                "messages": [{"role": _ROLES.get(m.type, m.type), "content": str(m.content)} for m in messages],
            },
        )

    def do_POST(self) -> None:
        match = THREAD.match(self.path)
        if not match or not match.group(2):
            self._reply(404, {"error": "use POST /threads/<thread>/turns"})
            return
        thread = match.group(1)
        try:
            length = int(self.headers.get("Content-Length") or 0)
            message = json.loads(self.rfile.read(min(length, 16384)) or b"{}").get("message", "")
        except (ValueError, AttributeError):
            message = ""
        if not isinstance(message, str) or not message.strip():
            self._reply(400, {"error": 'send a JSON body such as {"message": "Hello"}'})
            return
        config = {"configurable": {"thread_id": thread}}
        # The turn's message carries an ID of its own, so a failed turn can name
        # it to remove it again.
        message_id = str(uuid.uuid4())
        try:
            held = app.get_state(config).values.get("messages", [])
            result = app.invoke({"messages": [HumanMessage(content=message, id=message_id)]}, config)
        except Exception as error:
            try:
                _forget(config, message_id)
            except Exception as cleanup:
                # The reply still reports the turn's own error; this one is logged.
                print(
                    f"turn thread={thread} failed, and removing its message failed too: "
                    f"{type(cleanup).__name__}: {cleanup}",
                    flush=True,
                )
            self._reply(502, {"error": f"the turn failed: {type(error).__name__}: {error}"})
            return
        messages = result["messages"]
        reply = messages[-1]
        print(f"turn thread={thread} turn={_turns(messages)} messages_before={len(held)}", flush=True)
        self._reply(
            200,
            {
                "thread": thread,
                "turn": _turns(messages),
                "messages_before_this_turn": len(held),
                "answer": str(reply.content),
                "model": reply.response_metadata.get("model"),
                "agent_started_at": STARTED_AT,
            },
        )


def main() -> None:
    server = ThreadingHTTPServer(("0.0.0.0", PORT), Handler)
    server.daemon_threads = True
    # A stop request ends the service at once rather than after the stop timeout.
    signal.signal(signal.SIGTERM, lambda *_: threading.Thread(target=server.shutdown).start())
    print(f"quickstart agent listening on port {PORT}, started {STARTED_AT}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
