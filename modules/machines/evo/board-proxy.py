#!/usr/bin/env python3
"""Projects board MCP proxy for Hermes (localhost only, token injected server-side).

Hermes talks MCP (Streamable HTTP, JSON responses) to http://127.0.0.1:<port>/mcp without
credentials; this proxy adds the bearer token and forwards to the board's /mcp.

Denied tools (BOARD_DENY_TOOLS, comma-separated) are removed from tools/list and every
tools/call for them is answered with a tool error without reaching the board.
"""
import http.server
import json
import os
import sys
import urllib.error
import urllib.request

UPSTREAM = os.environ["BOARD_URL"].rstrip("/")  # https://host/mcp
PORT = int(os.environ.get("BOARD_PROXY_PORT", "9123"))
DENY = {t.strip() for t in os.environ.get("BOARD_DENY_TOOLS", "").split(",") if t.strip()}
TIMEOUT = 30
MAX_BODY = 1 << 20
FORWARD_REQ = ("content-type", "accept", "mcp-protocol-version")


def read_token():
    cred_dir = os.environ.get("CREDENTIALS_DIRECTORY")
    if cred_dir:
        with open(os.path.join(cred_dir, "token")) as f:
            return f.read().strip()
    return os.environ.get("BOARD_TOKEN", "")


TOKEN = read_token()
if not TOKEN:
    sys.exit("board-proxy: no token, refusing to start")


def denied_call(msg):
    """JSON-RPC response for a blocked tools/call (None if the message is allowed)."""
    if not isinstance(msg, dict) or msg.get("method") != "tools/call":
        return None
    name = (msg.get("params") or {}).get("name")
    if name not in DENY:
        return None
    return {
        "jsonrpc": "2.0",
        "id": msg.get("id"),
        "result": {
            "content": [{"type": "text", "text": f"error: tool {name!r} is not available to Hermes"}],
            "isError": True,
        },
    }


def filter_tools(msg):
    """Drop denied tools from a tools/list result."""
    if isinstance(msg, dict) and isinstance((msg.get("result") or {}).get("tools"), list):
        msg["result"]["tools"] = [t for t in msg["result"]["tools"] if t.get("name") not in DENY]
    return msg


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        print(f"[board-proxy] {format % args}", flush=True)

    def _send(self, code, body, ctype="application/json"):
        self.send_response(code)
        if body:
            self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def _error(self, code, msg):
        self._send(code, json.dumps({"error": msg}).encode())

    def do_POST(self):
        if self.path.partition("?")[0] != "/mcp":
            return self._error(404, "not found")
        length = int(self.headers.get("Content-Length") or 0)
        if length > MAX_BODY:
            return self._error(413, "body too large")
        raw = self.rfile.read(length)
        try:
            req = json.loads(raw)
        except ValueError as e:
            return self._error(400, f"invalid JSON: {e}")

        batch = isinstance(req, list)
        msgs = req if batch else [req]
        blocked = {id(m): d for m in msgs if (d := denied_call(m)) is not None}
        if blocked and not batch:
            return self._send(200, json.dumps(blocked[id(req)]).encode())
        forward = [m for m in msgs if id(m) not in blocked]
        local = list(blocked.values())
        if not forward:
            return self._send(200, json.dumps(local).encode())

        headers = {k: v for k in FORWARD_REQ if (v := self.headers.get(k))}
        headers["Authorization"] = f"Bearer {TOKEN}"
        body = json.dumps(forward if batch else forward[0]).encode()
        try:
            with urllib.request.urlopen(
                urllib.request.Request(UPSTREAM, data=body, method="POST", headers=headers), timeout=TIMEOUT
            ) as r:
                status, ctype, out = r.status, r.headers.get("Content-Type", ""), r.read()
        except urllib.error.HTTPError as e:
            status, ctype, out = e.code, e.headers.get("Content-Type", ""), e.read()
        except (urllib.error.URLError, OSError) as e:
            return self._error(502, f"board unreachable: {e}")

        # Notifications-only requests get 202 with no body; anything non-JSON is relayed as is.
        if not out or "application/json" not in ctype:
            if local:  # batch had blocked calls but upstream returned nothing parseable
                return self._send(200, json.dumps(local).encode())
            return self._send(status, out, ctype or "application/json")
        res = json.loads(out)
        res = [filter_tools(m) for m in res] if isinstance(res, list) else filter_tools(res)
        if batch:
            res = (res if isinstance(res, list) else [res]) + local
        self._send(status, json.dumps(res).encode())

    def do_GET(self):
        # Stateless server: no SSE stream to open.
        self._send(405, b"")

    def do_DELETE(self):
        self._send(405, b"")


def main():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"board-proxy listening on 127.0.0.1:{PORT} -> {UPSTREAM}, denied: {sorted(DENY)}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
