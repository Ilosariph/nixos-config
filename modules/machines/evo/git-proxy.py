#!/usr/bin/env python3
"""Fetch-only GitHub smart-HTTP proxy for Hermes (localhost only, token injected server-side).

Allowed (everything else -> 403, in particular git-receive-pack = push):
  GET  /<owner>/<repo>[.git]/info/refs?service=git-upload-pack
  POST /<owner>/<repo>[.git]/git-upload-pack
  GET  /_repos  -> "<owner>/<repo> private|public" per line: repos the token can read
                   (its private selection + all public ones), via api.github.com/user/repos
Bodies are streamed both ways; request/response headers relevant to git are passed through.
"""
import base64
import http.client
import http.server
import json
import os
import re
import sys
import urllib.parse

PORT = int(os.environ.get("GIT_PROXY_PORT", "9122"))
UPSTREAM = "github.com"
API = "api.github.com"
TIMEOUT = 300
CHUNK = 1 << 16


def read_token():
    cred_dir = os.environ.get("CREDENTIALS_DIRECTORY")
    if cred_dir:
        with open(os.path.join(cred_dir, "token")) as f:
            return f.read().strip()
    return os.environ.get("GIT_PROXY_TOKEN", "")


TOKEN = read_token()
if not TOKEN:
    sys.exit("git-proxy: no token, refusing to start")
AUTH = "Basic " + base64.b64encode(f"x-access-token:{TOKEN}".encode()).decode()

REPO = r"/[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+?(?:\.git)?"
INFO_REFS = re.compile(rf"^({REPO})/info/refs$")
UPLOAD_PACK = re.compile(rf"^({REPO})/git-upload-pack$")
REQ_HEADERS = ("content-type", "content-encoding", "accept", "accept-encoding", "git-protocol")
RES_HEADERS = ("content-type", "content-encoding", "cache-control", "expires", "pragma")


class Handler(http.server.BaseHTTPRequestHandler):
    protocol_version = "HTTP/1.0"  # response ends at connection close -> no re-chunking needed

    def refuse(self, code, msg):
        body = (msg + "\n").encode()
        self.send_response(code)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def read_body(self):
        if self.headers.get("Transfer-Encoding", "").lower() == "chunked":
            out = bytearray()
            while True:
                size = int(self.rfile.readline().split(b";")[0].strip(), 16)
                if size == 0:
                    while self.rfile.readline() not in (b"\r\n", b"\n", b""):
                        pass
                    return bytes(out)
                out += self.rfile.read(size)
                self.rfile.readline()
        return self.rfile.read(int(self.headers.get("Content-Length", "0")))

    def forward(self, method, path, body=None):
        headers = {k: v for k, v in self.headers.items() if k.lower() in REQ_HEADERS}
        headers["Authorization"] = AUTH
        headers["User-Agent"] = self.headers.get("User-Agent", "git/2")
        conn = http.client.HTTPSConnection(UPSTREAM, timeout=TIMEOUT)
        try:
            conn.request(method, path, body=body, headers=headers)
            res = conn.getresponse()
            self.send_response(res.status)
            for k, v in res.getheaders():
                if k.lower() in RES_HEADERS:
                    self.send_header(k, v)
            self.end_headers()
            while chunk := res.read(CHUNK):
                self.wfile.write(chunk)
        except OSError as e:
            self.log_error("upstream: %s", e)
            if not self.wfile.closed:
                try:
                    self.refuse(502, "upstream error")
                except OSError:
                    pass
        finally:
            conn.close()

    def list_repos(self):
        names, page = [], 1
        while True:
            conn = http.client.HTTPSConnection(API, timeout=60)
            try:
                conn.request("GET", f"/user/repos?per_page=100&affiliation=owner&page={page}", headers={
                    "Authorization": f"Bearer {TOKEN}",
                    "Accept": "application/vnd.github+json",
                    "User-Agent": "hermes-git-proxy",
                })
                res = conn.getresponse()
                data = res.read()
            except OSError as e:
                self.log_error("api: %s", e)
                return self.refuse(502, "upstream error")
            finally:
                conn.close()
            if res.status != 200:
                return self.refuse(502, f"github api: HTTP {res.status}")
            repos = json.loads(data)
            names += [f"{r['full_name']} {'private' if r['private'] else 'public'}" for r in repos]
            if len(repos) < 100:
                break
            page += 1
        body = "".join(n + "\n" for n in sorted(names, key=str.lower)).encode()
        self.send_response(200)
        self.send_header("Content-Type", "text/plain")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def do_GET(self):
        url = urllib.parse.urlsplit(self.path)
        if url.path == "/_repos":
            return self.list_repos()
        q = urllib.parse.parse_qs(url.query)
        if not INFO_REFS.match(url.path) or q.get("service") != ["git-upload-pack"]:
            return self.refuse(403, "read-only proxy: only fetch/clone is allowed")
        self.forward("GET", url.path + "?service=git-upload-pack")

    def do_POST(self):
        url = urllib.parse.urlsplit(self.path)
        if not UPLOAD_PACK.match(url.path) or url.query:
            return self.refuse(403, "read-only proxy: only fetch/clone is allowed")
        self.forward("POST", url.path, self.read_body())

    def do_PUT(self):
        self.refuse(403, "read-only proxy: only fetch/clone is allowed")

    do_DELETE = do_PATCH = do_HEAD = do_PUT


if __name__ == "__main__":
    http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler).serve_forever()
