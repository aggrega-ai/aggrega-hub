# SPDX-License-Identifier: Apache-2.0
# Copyright 2026 Cognitio S.r.l.
"""quickstart-ask: send one turn to the agent running in the same container.

  quickstart-ask <thread> <message...>   one turn on that conversation
  quickstart-ask --history <thread>      the conversation so far
"""

from __future__ import annotations

import json
import sys
import urllib.error
import urllib.request

AGENT = "http://127.0.0.1:8000"


def main(argv: list[str]) -> int:
    if len(argv) >= 2 and argv[0] == "--history":
        request = urllib.request.Request(f"{AGENT}/threads/{argv[1]}")
    elif len(argv) >= 2 and not argv[0].startswith("-"):
        body = json.dumps({"message": " ".join(argv[1:])}).encode()
        request = urllib.request.Request(
            f"{AGENT}/threads/{argv[0]}/turns", data=body, headers={"Content-Type": "application/json"}
        )
    else:
        print(__doc__.strip(), file=sys.stderr)
        return 2
    try:
        with urllib.request.urlopen(request, timeout=600) as response:
            sys.stdout.write(response.read().decode())
            return 0
    except urllib.error.HTTPError as error:
        sys.stdout.write(error.read().decode())
        return 1


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
