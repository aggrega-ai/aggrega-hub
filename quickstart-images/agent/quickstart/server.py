# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Cognitio S.r.l.
"""The agent's HTTP service, on port 8000.

  POST /threads/<thread>/turns   {"message": "..."}  one turn on that conversation
  GET  /threads/<thread>                             the conversation so far
  GET  /healthz                                      whether the store answers

A turn's answer says how many messages the conversation already held when the
turn began, read back from the store, and when the serving process started, so
a conversation continuing across a restart is visible in the answer itself.
"""

from __future__ import annotations

import json
import re
import signal
import sys
import threading
from datetime import datetime, timezone
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer

from langchain_core.messages import HumanMessage

from quickstart.graph import _ROLES, app, store

PORT = 8000
STARTED_AT = datetime.now(timezone.utc).isoformat(timespec="seconds")
THREAD = re.compile(r"^/threads/([A-Za-z0-9._-]{1,64})(/turns)?$")


def _turns(messages) -> int:
    return sum(1 for m in messages if m.type == "human")


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
        try:
            held = app.get_state(config).values.get("messages", [])
            result = app.invoke({"messages": [HumanMessage(content=message)]}, config)
        except Exception as error:
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
