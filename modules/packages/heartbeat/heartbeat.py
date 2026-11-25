"""Signed UDP heartbeats between servers, Discord alerts, Wake-on-LAN.

daemon:   heartbeat daemon <config.json>
CLI:      heartbeat status | maint <30m|2h|...> | done | shutdown-hook

Packet = HMAC-SHA256(key, body) (32 bytes) + body (JSON):
  {"from", "ts", "ack", "prio", "watching": [...], "announce": {...} | null}
announce = {"kind": "reboot"|"poweroff"|"maint", "until": ts|null, "id": str}

Every node sends a heartbeat every `interval` s to peers with an address.
Hubs (`reply`) answer each non-ack heartbeat with an ack to its source address,
so nodes behind NAT see the hub without the hub reaching them.
Announcements live in RUN/announce.json (written by the CLI, read by the daemon)
and ride along in every packet until they expire or are cleared.
"""

import hashlib
import hmac
import json
import os
import socket
import subprocess
import sys
import threading
import time
import urllib.request

RUN = "/run/heartbeat"
ANNOUNCE = f"{RUN}/announce.json"
STATE = f"{RUN}/state.json"


def log(*a):
    print(*a, flush=True)


def fmt_dur(s):
    s = int(max(s, 0))
    if s < 90:
        return f"{s}s"
    if s < 5400:
        return f"{s // 60}m"
    return f"{s // 3600}h{(s % 3600) // 60:02d}m"


def parse_dur(t):
    mult = {"s": 1, "m": 60, "h": 3600, "d": 86400}
    if t and t[-1] in mult:
        return int(float(t[:-1]) * mult[t[-1]])
    return int(float(t) * 60)  # bare number = minutes


def read_json(path):
    try:
        with open(path) as f:
            return json.load(f)
    except (OSError, ValueError):
        return None


def write_json(path, data):
    tmp = f"{path}.tmp"
    with open(tmp, "w") as f:
        json.dump(data, f)
    os.chmod(tmp, 0o644)
    os.replace(tmp, path)


class Peer:
    def __init__(self, name, c):
        self.name = name
        self.addr = c.get("address")
        self.send = c.get("send", False) and self.addr is not None
        self.watch = c.get("watch", True)
        self.mac = c.get("mac")
        self.last_seen = None
        self.last_ts = 0.0
        self.src = None  # last source address (hub replies there)
        self.prio = 1000
        self.watching = []
        self.announce = None
        self.status = "unknown"  # up | down | reboot | poweroff | maint
        self.since = None  # when the current non-up status started
        self.alerted = False
        self.wol_count = 0
        self.wol_last = 0.0
        self.sent_announce = None  # id of our announce last delivered to this peer


class Daemon:
    def __init__(self, cfg):
        self.cfg = cfg
        self.me = cfg["self"]
        self.interval = cfg["interval"]
        self.timeout = cfg["timeout"]
        self.reboot_window = cfg["rebootWindow"]
        self.prio = cfg["priority"]
        self.reply = cfg["reply"]
        self.wol_max = cfg["wolAttempts"]
        self.wol_every = cfg["wolInterval"]
        cred = os.environ.get("CREDENTIALS_DIRECTORY", "")
        with open(os.path.join(cred, "key"), "rb") as f:
            self.key = f.read().strip()
        try:
            with open(os.path.join(cred, "webhook")) as f:
                self.webhook = f.read().strip() or None
        except OSError:
            self.webhook = None
        self.peers = {n: Peer(n, c) for n, c in cfg["peers"].items()}
        self.start = time.time()
        self.own_announce = None
        self.announce_mtime = None
        self.sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
        self.sock.bind(("0.0.0.0", cfg["port"]))
        self.sock.settimeout(1.0)

    # ---- wire -------------------------------------------------------------
    def packet(self, ack):
        body = json.dumps({
            "from": self.me,
            "ts": time.time(),
            "ack": ack,
            "prio": self.prio,
            "watching": [p.name for p in self.peers.values() if p.watch],
            "announce": self.own_announce,
        }).encode()
        return hmac.new(self.key, body, hashlib.sha256).digest() + body

    def sendto(self, peer, addr, ack=False):
        try:
            self.sock.sendto(self.packet(ack), addr)
            if self.own_announce:
                peer.sent_announce = self.own_announce["id"]
        except OSError as e:
            log(f"send to {peer.name} {addr}: {e}")

    def send_all(self):
        for p in self.peers.values():
            if p.send:
                self.sendto(p, (p.addr, self.cfg["port"]))

    def receive(self, data, src):
        if len(data) < 33:
            return
        mac, body = data[:32], data[32:]
        if not hmac.compare_digest(mac, hmac.new(self.key, body, hashlib.sha256).digest()):
            log(f"bad signature from {src[0]}")
            return
        try:
            m = json.loads(body)
        except ValueError:
            return
        p = self.peers.get(m.get("from"))
        now = time.time()
        ts = m.get("ts", 0)
        if p is None or abs(now - ts) > 120 or ts <= p.last_ts:
            return  # unknown, clock skew or replay
        p.last_ts = ts
        p.last_seen = now
        p.src = src
        p.prio = m.get("prio", 1000)
        p.watching = m.get("watching", [])
        p.announce = m.get("announce")
        if self.reply and not m.get("ack"):
            self.sendto(p, src, ack=True)

    # ---- announcements -----------------------------------------------------
    def load_announce(self):
        try:
            mtime = os.stat(ANNOUNCE).st_mtime
        except OSError:
            mtime = None
        if mtime != self.announce_mtime:
            self.announce_mtime = mtime
            a = read_json(ANNOUNCE) if mtime else None
            if a != self.own_announce:
                self.own_announce = a
                log(f"own announcement: {a}")
                self.send_all()  # deliver right away
        a = self.own_announce
        if a and a.get("until") and a["until"] < time.time():
            log("own announcement expired")
            self.own_announce = None
            try:
                os.remove(ANNOUNCE)
            except OSError:
                pass

    # ---- alerting ------------------------------------------------------------
    def fresh(self, p, now):
        return p.last_seen is not None and now - p.last_seen < self.timeout

    def responsible(self, target, now):
        """Of all live nodes watching target, the one with the lowest priority alerts."""
        cands = [(self.prio, self.me)]
        for q in self.peers.values():
            if q is not target and self.fresh(q, now) and target.name in q.watching:
                cands.append((q.prio, q.name))
        return min(cands)[1] == self.me

    def notify(self, target, text, now):
        log(text)
        if not self.webhook or not self.responsible(target, now):
            return
        body = json.dumps({"content": f"{text}  ·  _{self.me}_"}).encode()

        def post():
            req = urllib.request.Request(self.webhook, data=body, headers={
                "Content-Type": "application/json", "User-Agent": "heartbeat/1",
            })
            for _ in range(3):
                try:
                    urllib.request.urlopen(req, timeout=10).close()
                    return
                except Exception as e:  # noqa: BLE001
                    log(f"discord: {e}")
                    time.sleep(5)

        threading.Thread(target=post, daemon=True).start()

    def pingable(self, p):
        if not p.addr:
            return False
        try:
            r = subprocess.run(["ping", "-c", "1", "-W", "2", p.addr],
                               stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
        except OSError as e:
            log(f"ping: {e}")
            return False
        return r.returncode == 0

    def wake(self, p):
        mac = bytes.fromhex(p.mac.replace(":", "").replace("-", ""))
        pkt = b"\xff" * 6 + mac * 16
        try:
            with socket.socket(socket.AF_INET, socket.SOCK_DGRAM) as s:
                s.setsockopt(socket.SOL_SOCKET, socket.SO_BROADCAST, 1)
                for port in (9, 7):
                    s.sendto(pkt, ("255.255.255.255", port))
        except OSError as e:
            log(f"wol: {e}")

    def set_status(self, p, status, now):
        if p.status != status:
            log(f"{p.name}: {p.status} -> {status}")
            p.status = status
            p.since = now

    def check(self, p, now):
        a = p.announce
        if a and a.get("until") and a["until"] < now:
            a = None
        fresh = self.fresh(p, now)
        name = f"**{p.name}**"

        if a and a.get("kind") in ("reboot", "poweroff", "maint"):
            # Announced: no alerts or WoL until it expires or the host is back.
            if p.status != a["kind"]:
                prev = p.status
                self.set_status(p, a["kind"], now)
                p.alerted = False
                p.wol_count = 0
                if prev != "unknown":
                    until = f" (expected back within {fmt_dur(a['until'] - now)})" if a.get("until") else ""
                    msg = {
                        "reboot": f"🔁 {name} is rebooting{until}",
                        "poweroff": f"⏻ {name} is powering off (no WoL until it is back)",
                        "maint": f"🛠 {name} in maintenance for {fmt_dur(a['until'] - now)}" if a.get("until") else f"🛠 {name} in maintenance",
                    }[a["kind"]]
                    self.notify(p, msg, now)
            return

        if fresh:
            if p.status in ("down", "reboot", "poweroff", "maint"):
                took = fmt_dur(now - p.since) if p.since else "?"
                if p.status == "down" and p.alerted:
                    self.notify(p, f"🟢 {name} is back up (down {took})", now)
                elif p.status in ("reboot", "poweroff"):
                    self.notify(p, f"🟢 {name} is back up ({p.status} took {took})", now)
                elif p.status == "maint":
                    self.notify(p, f"🟢 {name} maintenance over", now)
            self.set_status(p, "up", now)
            p.alerted = False
            p.wol_count = 0
            return

        # Stale and no (valid) announcement.
        if now - self.start < self.timeout:
            return  # grace period after our own start
        if p.status != "down":
            was = p.status
            self.set_status(p, "down", now)
            if was in ("reboot", "maint") and p.announce:
                why = f"didn't come back after {'reboot' if was == 'reboot' else 'maintenance'}"
            else:
                last = f"last heartbeat {fmt_dur(now - p.last_seen)} ago" if p.last_seen else "no heartbeat since I started"
                why = f"is down ({last})"
            alive = p.mac and self.pingable(p)
            if alive:
                why += ", but answers ping (heartbeat service down?)"
            self.notify(p, f"🔴 {name} {why}", now)
            p.alerted = True
        if p.mac and p.wol_count < self.wol_max and now - p.wol_last >= self.wol_every:
            p.wol_last = now
            if self.pingable(p):
                return
            p.wol_count += 1
            self.wake(p)
            if self.responsible(p, now):
                extra = "" if p.wol_count < self.wol_max else ", last try"
                self.notify(p, f"⚡ Wake-on-LAN sent to {name} ({p.wol_count}/{self.wol_max}{extra})", now)
            else:
                log(f"wol sent to {p.name} ({p.wol_count})")

    def dump_state(self, now):
        write_json(STATE, {
            "self": self.me,
            "time": now,
            "announce": self.own_announce,
            "peers": {
                p.name: {
                    "status": p.status,
                    "lastSeen": p.last_seen,
                    "since": p.since,
                    "announce": p.announce,
                    "watching": p.watching,
                    "prio": p.prio,
                    "watched": p.watch,
                    "sentAnnounce": p.sent_announce,
                    "responsible": self.responsible(p, now),
                }
                for p in self.peers.values()
            },
        })

    def run(self):
        log(f"{self.me}: listening on udp/{self.cfg['port']}, peers {list(self.peers)}")
        next_send = 0.0
        while True:
            try:
                data, src = self.sock.recvfrom(4096)
                self.receive(data, src)
            except socket.timeout:
                pass
            except OSError as e:
                log(f"recv: {e}")
            now = time.time()
            self.load_announce()
            if now >= next_send:
                self.send_all()
                next_send = now + self.interval
            for p in self.peers.values():
                if p.watch:
                    self.check(p, now)
            self.dump_state(now)


# ---- CLI ---------------------------------------------------------------------
def announce(kind, until):
    a = {"kind": kind, "until": until, "id": f"{kind}-{time.time()}"}
    write_json(ANNOUNCE, a)
    return a


def wait_delivered(a, limit):
    """Wait until the daemon sent announcement a to every live peer."""
    end = time.time() + limit
    while time.time() < end:
        s = read_json(STATE) or {}
        peers = s.get("peers", {})
        pending = [n for n, p in peers.items()
                   if p.get("status") == "up" and p.get("sentAnnounce") != a["id"]]
        if not pending:
            return True
        time.sleep(1)
    print(f"heartbeat: not delivered to {', '.join(pending)}", file=sys.stderr)
    return False


def cli(args):
    cmd = args[0] if args else "status"
    if cmd == "status":
        s = read_json(STATE)
        if not s:
            sys.exit("heartbeat: no state (daemon not running?)")
        now = time.time()
        if s.get("announce"):
            a = s["announce"]
            u = f" for {fmt_dur(a['until'] - now)}" if a.get("until") else ""
            print(f"{s['self']}: announced {a['kind']}{u}")
        for n, p in s["peers"].items():
            seen = fmt_dur(now - p["lastSeen"]) + " ago" if p["lastSeen"] else "never"
            flags = []
            if not p["watched"]:
                flags.append("not watched")
            if p["responsible"]:
                flags.append("alerting")
            print(f"{n:<14} {p['status']:<9} last seen {seen:<10} {' '.join(flags)}")
        return
    if os.geteuid() != 0:
        os.execvp("sudo", ["sudo", "/run/current-system/sw/bin/heartbeat", *args])
    if cmd == "maint":
        if len(args) != 2:
            sys.exit("usage: heartbeat maint <duration, e.g. 30m, 2h>")
        a = announce("maint", time.time() + parse_dur(args[1]))
        wait_delivered(a, 45)
        print(f"heartbeat: maintenance for {fmt_dur(a['until'] - time.time())}, peers won't alert or wake this host")
    elif cmd == "done":
        try:
            os.remove(ANNOUNCE)
        except FileNotFoundError:
            pass
        print("heartbeat: announcement cleared")
    elif cmd == "shutdown-hook":
        jobs = subprocess.run(["systemctl", "list-jobs", "--no-legend", "--plain"],
                              capture_output=True, text=True).stdout
        if "reboot.target" in jobs or "kexec.target" in jobs or "soft-reboot.target" in jobs:
            a = announce("reboot", time.time() + int(args[1]))
        elif "poweroff.target" in jobs or "halt.target" in jobs:
            a = announce("poweroff", None)
        else:
            return  # unit stopped for another reason
        # Hub peers (nodes behind NAT) only get it with their next heartbeat's ack.
        wait_delivered(a, int(args[2]) if len(args) > 2 else 45)
    else:
        sys.exit(f"heartbeat: unknown command {cmd!r} (status | maint <dur> | done)")


if __name__ == "__main__":
    if len(sys.argv) >= 3 and sys.argv[1] == "daemon":
        with open(sys.argv[2]) as f:
            Daemon(json.load(f)).run()
    else:
        cli(sys.argv[1:])
