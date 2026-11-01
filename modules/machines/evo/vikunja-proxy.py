#!/usr/bin/env python3
"""Vikunja API proxy for Hermes (localhost only, token injected server-side).

Reads: any GET/HEAD under /api/v1/ is passed through.
Writes: only these, and only on tasks carrying the Hermes label (VIKUNJA_LABEL):
  PUT    /api/v1/projects/<pid>/tasks          create task -> Hermes label added automatically
  POST   /api/v1/tasks/<id>                    update task (partial: only given fields change)
  DELETE /api/v1/tasks/<id>                    delete task
  PUT    /api/v1/tasks/<id>/labels             add label {"label_id": n}
  DELETE /api/v1/tasks/<id>/labels/<label_id>  remove label (not the Hermes label itself)
Everything else is rejected (403). The label check reads the task fresh from Vikunja on
every write, so removing the label in Vikunja revokes access immediately.
"""
import http.server
import json
import os
import re
import sys
import threading
import urllib.error
import urllib.parse
import urllib.request

UPSTREAM = os.environ["VIKUNJA_URL"].rstrip("/")
PORT = int(os.environ.get("VIKUNJA_PROXY_PORT", "9121"))
LABEL = os.environ.get("VIKUNJA_LABEL", "Hermes")
TIMEOUT = 30
MAX_BODY = 1 << 20


def read_token():
    cred_dir = os.environ.get("CREDENTIALS_DIRECTORY")
    if cred_dir:
        with open(os.path.join(cred_dir, "token")) as f:
            return f.read().strip()
    return os.environ.get("VIKUNJA_TOKEN", "")


TOKEN = read_token()
if not TOKEN:
    sys.exit("vikunja-proxy: no API token, refusing to start")

# Fields Hermes may set on create/update. Everything else (labels, assignees, buckets,
# attachments, relations, ids, ...) is rejected so a write can't reach other objects.
TASK_FIELDS = {
    "title", "description", "done", "due_date", "start_date", "end_date", "priority",
    "percent_done", "repeat_after", "repeat_mode", "reminders", "hex_color", "is_favorite",
}
UPDATE_FIELDS = TASK_FIELDS | {"project_id"}

# Passed back to Hermes on reads (pagination info lives in headers).
PASS_HEADERS = ("content-type", "x-pagination-total-pages", "x-pagination-result-count")

GET_PATH = re.compile(r"^/api/v1/[A-Za-z0-9_\-./]*$")
CREATE = re.compile(r"^/api/v1/projects/(\d+)/tasks$")
TASK = re.compile(r"^/api/v1/tasks/(\d+)$")
TASK_LABELS = re.compile(r"^/api/v1/tasks/(\d+)/labels$")
TASK_LABEL = re.compile(r"^/api/v1/tasks/(\d+)/labels/(\d+)$")


class Refuse(Exception):
    def __init__(self, code, msg):
        super().__init__(msg)
        self.code, self.msg = code, msg


def upstream(method, path, body=None, query=""):
    url = UPSTREAM + path + (f"?{query}" if query else "")
    headers = {"Authorization": f"Bearer {TOKEN}", "Accept": "application/json"}
    data = None
    if body is not None:
        data = json.dumps(body).encode()
        headers["Content-Type"] = "application/json"
    req = urllib.request.Request(url, data=data, method=method, headers=headers)
    try:
        with urllib.request.urlopen(req, timeout=TIMEOUT) as r:
            return r.status, r.headers, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.headers, e.read()
    except (urllib.error.URLError, OSError) as e:
        raise Refuse(502, f"upstream unreachable: {e}")


def upstream_json(method, path, body=None, query="", ok=(200, 201)):
    status, _, raw = upstream(method, path, body, query)
    if status not in ok:
        raise Refuse(status, f"vikunja {method} {path} -> {status}: {raw[:500].decode(errors='replace')}")
    return json.loads(raw) if raw else None


_label_id = None
_label_lock = threading.Lock()


def hermes_label_id():
    """Id of the Hermes label, created on first use if missing. Ambiguity fails closed."""
    global _label_id
    with _label_lock:
        if _label_id is not None:
            return _label_id
        matches, page = [], 1
        while True:
            status, headers, raw = upstream(
                "GET", "/api/v1/labels", query=urllib.parse.urlencode({"s": LABEL, "page": page}))
            if status != 200:
                raise Refuse(502, f"label lookup failed: {status}")
            matches += [l for l in (json.loads(raw) or []) if l.get("title") == LABEL]
            if page >= int(headers.get("x-pagination-total-pages") or 1):
                break
            page += 1
        if len(matches) > 1:
            raise Refuse(409, f"{len(matches)} labels titled {LABEL!r} exist; keep exactly one")
        if matches:
            _label_id = matches[0]["id"]
        else:
            _label_id = upstream_json("PUT", "/api/v1/labels", {"title": LABEL})["id"]
            print(f"[vikunja-proxy] created label {LABEL!r} id={_label_id}", flush=True)
        return _label_id


def hermes_task(task_id):
    """Fetch the task; refuse unless it carries the Hermes label."""
    status, _, raw = upstream("GET", f"/api/v1/tasks/{task_id}")
    if status != 200:
        raise Refuse(404 if status in (403, 404) else 502, f"task {task_id} not found")
    task = json.loads(raw)
    label_id = hermes_label_id()
    if not any(l.get("id") == label_id for l in task.get("labels") or []):
        raise Refuse(403, f"task {task_id} has no {LABEL!r} label; only {LABEL}-labelled tasks may be changed")
    return task


def check_fields(body, allowed):
    if not isinstance(body, dict):
        raise Refuse(400, "body must be a JSON object")
    bad = sorted(set(body) - allowed)
    if bad:
        raise Refuse(400, f"fields not allowed: {bad}; allowed: {sorted(allowed)}")


class Handler(http.server.BaseHTTPRequestHandler):
    def log_message(self, format, *args):
        print(f"[vikunja-proxy] {format % args}", flush=True)

    def _send(self, code, body, headers=None):
        self.send_response(code)
        for k, v in (headers or {}).items():
            self.send_header(k, v)
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        if self.command != "HEAD":
            self.wfile.write(body)

    def _send_json(self, code, data):
        self._send(code, json.dumps(data).encode(), {"Content-Type": "application/json"})

    def _relay(self, status, headers, raw):
        self._send(status, raw, {k: headers[k] for k in PASS_HEADERS if headers.get(k)})

    def _body(self):
        length = int(self.headers.get("Content-Length") or 0)
        if length > MAX_BODY:
            raise Refuse(413, "body too large")
        try:
            return json.loads(self.rfile.read(length)) if length else {}
        except ValueError as e:
            raise Refuse(400, f"invalid JSON: {e}")

    def _handle(self, fn):
        path, _, query = self.path.partition("?")
        try:
            fn(path, query)
        except Refuse as e:
            self._send_json(e.code, {"error": e.msg})
        except Exception as e:
            self._send_json(500, {"error": f"proxy error: {e!r}"})

    # Reads -----------------------------------------------------------------

    def _get(self, path, query):
        if not GET_PATH.match(path) or ".." in path:
            raise Refuse(404, "not found")
        self._relay(*upstream("GET", path, query=query))

    def do_GET(self):
        self._handle(self._get)

    def do_HEAD(self):
        self._handle(self._get)

    # Writes ----------------------------------------------------------------

    def _put(self, path, query):
        if m := CREATE.match(path):
            body = self._body()
            check_fields(body, TASK_FIELDS)
            label_id = hermes_label_id()
            task = upstream_json("PUT", f"/api/v1/projects/{m[1]}/tasks", body)
            status, _, _ = upstream("PUT", f"/api/v1/tasks/{task['id']}/labels", {"label_id": label_id})
            if status not in (200, 201):
                # Never leave an unlabelled Hermes task behind (it could not be managed later).
                upstream("DELETE", f"/api/v1/tasks/{task['id']}")
                raise Refuse(502, f"could not label new task ({status}); task removed again")
            return self._relay(*upstream("GET", f"/api/v1/tasks/{task['id']}"))
        if m := TASK_LABELS.match(path):
            body = self._body()
            check_fields(body, {"label_id"})
            if not isinstance(body.get("label_id"), int):
                raise Refuse(400, "label_id (int) required")
            hermes_task(m[1])
            return self._relay(*upstream("PUT", path, {"label_id": body["label_id"]}))
        raise Refuse(403, "write not allowed")

    def _post(self, path, query):
        if m := TASK.match(path):
            body = self._body()
            check_fields(body, UPDATE_FIELDS)
            # Vikunja's update resets omitted fields, so merge onto the current task.
            task = hermes_task(m[1])
            task.update(body)
            task["id"] = int(m[1])
            return self._relay(*upstream("POST", path, task))
        raise Refuse(403, "write not allowed")

    def _delete(self, path, query):
        if m := TASK.match(path):
            hermes_task(m[1])
            return self._relay(*upstream("DELETE", path))
        if m := TASK_LABEL.match(path):
            hermes_task(m[1])
            if int(m[2]) == hermes_label_id():
                raise Refuse(403, f"the {LABEL!r} label can only be removed in Vikunja itself")
            return self._relay(*upstream("DELETE", path))
        raise Refuse(403, "write not allowed")

    def do_PUT(self):
        self._handle(self._put)

    def do_POST(self):
        self._handle(self._post)

    def do_DELETE(self):
        self._handle(self._delete)

    def do_PATCH(self):
        self._send_json(403, {"error": "write not allowed"})


def main():
    server = http.server.ThreadingHTTPServer(("127.0.0.1", PORT), Handler)
    print(f"vikunja-proxy listening on 127.0.0.1:{PORT} -> {UPSTREAM}, label {LABEL!r}", flush=True)
    server.serve_forever()


if __name__ == "__main__":
    main()
