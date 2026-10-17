#!/usr/bin/env python3
"""Nix config eval/build endpoint for Hermes (localhost only).

GET  /health                                  -> {"status": "ok", ...}   (no auth)
POST /build {"host": "evo", "mode": "build"}  -> result JSON             (Bearer token)
     mode: "eval"  = evaluate toplevel drvPath only (fast, works for any arch)
           "build" = nix build toplevel, no result link (default)
"""
import http.server
import json
import os
import subprocess
import sys
import time

REPO_DIR = os.environ["NIX_EVAL_REPO_DIR"]
HOSTS = set(filter(None, os.environ.get("NIX_EVAL_HOSTS", "").split(",")))
PORT = int(os.environ.get("NIX_EVAL_PORT", "9120"))
TIMEOUT = int(os.environ.get("NIX_EVAL_TIMEOUT", "3600"))
TOKEN = os.environ.get("NIX_EVAL_TOKEN", "")
MAX_OUTPUT = 20000  # chars of stderr tail returned to the caller

if not TOKEN:
    sys.exit("nix-eval: NIX_EVAL_TOKEN not set, refusing to start")

# path: (not git+file:) so files Hermes created but did not `git add` are included.
FLAKE = f"path:{REPO_DIR}"


def nix_cmd(host, mode):
    attr = f"{FLAKE}#nixosConfigurations.{host}.config.system.build.toplevel"
    if mode == "eval":
        return ["nix", "eval", "--raw", f"{attr}.drvPath"]
    return ["nix", "build", "--no-link", "--print-out-paths", "-L", attr]


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        print(f"[nix-eval] {format % args}", flush=True)

    def _send_json(self, code, data):
        body = json.dumps(data, indent=2).encode()
        self.send_response(code)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        if self.path == "/health":
            self._send_json(200, {"status": "ok", "repo": REPO_DIR, "hosts": sorted(HOSTS)})
        else:
            self._send_json(404, {"error": "not found"})

    def do_POST(self):
        if self.path != "/build":
            return self._send_json(404, {"error": "not found"})
        if self.headers.get("Authorization", "") != f"Bearer {TOKEN}":
            return self._send_json(401, {"error": "unauthorized"})

        try:
            length = int(self.headers.get("Content-Length", 0))
            body = json.loads(self.rfile.read(length)) if length else {}
            if not isinstance(body, dict):
                raise ValueError("body must be a JSON object")
        except ValueError as e:
            return self._send_json(400, {"error": f"bad request: {e}"})

        host = body.get("host", "evo")
        mode = body.get("mode", "build")
        if host not in HOSTS:
            return self._send_json(400, {"error": f"unknown host {host!r}", "hosts": sorted(HOSTS)})
        if mode not in ("eval", "build"):
            return self._send_json(400, {"error": "mode must be 'eval' or 'build'"})

        cmd = nix_cmd(host, mode)
        start = time.time()
        try:
            res = subprocess.run(cmd, capture_output=True, text=True, timeout=TIMEOUT)
            success, code, stdout, stderr = res.returncode == 0, res.returncode, res.stdout, res.stderr
        except subprocess.TimeoutExpired as e:
            success, code, stdout = False, -1, ""
            stderr = (e.stderr or b"").decode(errors="replace") if isinstance(e.stderr, bytes) else (e.stderr or "")
            stderr += f"\n{mode} timed out after {TIMEOUT}s"

        self._send_json(200, {
            "success": success,
            "exit_code": code,
            "host": host,
            "mode": mode,
            "command": " ".join(cmd),
            "stdout": stdout.strip(),
            "stderr": stderr.strip()[-MAX_OUTPUT:],
            "elapsed_seconds": round(time.time() - start, 1),
        })


def main():
    # Single-threaded on purpose: one eval/build at a time.
    server = http.server.HTTPServer(("127.0.0.1", PORT), Handler)
    print(f"nix-eval listening on 127.0.0.1:{PORT}, repo {REPO_DIR}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
