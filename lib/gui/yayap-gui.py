#!/usr/bin/env python3
"""YaYaP GUI — the Control Center as a desktop app, YaST-style.

Serves a small web UI on 127.0.0.1 only (random port + secret token), opens it in
an app window, and runs the real `yayap` modules for everything. No extra Python
packages: just python3 plus GTK-WebKit, Qt-WebEngine, pywebview or a browser.
Started by:  yayap gui   (yayap gui --no-window just prints the URL)
"""
import argparse, json, os, pwd, re, secrets, shutil, signal, stat, subprocess, sys, tempfile, threading, time
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from urllib.parse import urlparse, parse_qs

HERE = os.path.dirname(os.path.abspath(__file__))
LOGO = os.path.join(HERE, "yayap.svg")
TOKEN = secrets.token_urlsafe(24)
YAYAP = "yayap"
PORT = 0
JOBS, JOBS_LOCK = {}, threading.Lock()
LAST_PING = [time.time()]
ANSI = re.compile(r"\x1b\[[0-9;?]*[A-Za-z]")
PLACEHOLDER = re.compile(r"^\{(.+)\}$")
MAX_LINES = 5000


# ───────────────────────── the module tree (straight from `yayap center --tsv`) ─────────────────────────
def load_tree():
    out = subprocess.run([YAYAP, "--no-color", "center", "--tsv"], capture_output=True, text=True, check=True).stdout
    cats, mods = [], {}
    for line in out.splitlines():
        f = line.split("\t")
        if f[0] == "M" and len(f) == 5:
            _, cat, name, icon, about = f
            if not cats or cats[-1]["name"] != cat:
                cats.append({"name": cat, "modules": []})
            mods[name] = {"name": name, "icon": icon, "about": about, "category": cat, "actions": []}
            cats[-1]["modules"].append(mods[name])
        elif f[0] == "A" and len(f) == 4 and f[1] in mods:
            _, name, label, template = f
            fields = []
            for tok in template.split():
                m = PLACEHOLDER.match(tok)
                if m:
                    p = m.group(1)
                    many = p.endswith("...")
                    fields.append({"prompt": p.rstrip(".").replace("_", " "), "many": many})
            mods[name]["actions"].append({"label": label, "template": template, "fields": fields})
    return cats, mods


def expand(template, values):
    """Fill a 'args template' with the form values -> argv list (never goes through a shell)."""
    args, vi = [], 0
    for tok in template.split():
        m = PLACEHOLDER.match(tok)
        if not m:
            args.append(tok)
            continue
        if vi >= len(values):
            raise ValueError("missing a value")
        v = str(values[vi]).strip()
        vi += 1
        if not v:
            raise ValueError("empty value")
        args.extend(v.split() if m.group(1).endswith("...") else [v])
    return args


# ───────────────────────── jobs ─────────────────────────
class Job:
    def __init__(self, jid, argv):
        self.id, self.argv = jid, argv
        self.lines, self.done, self.rc = [], False, None
        self.ask = None                      # {"kind": password|secret|confirm, "prompt": ...}
        self.answer, self.answered = None, threading.Event()
        self.proc = None

    def run(self, helper):
        env = dict(os.environ, NO_COLOR="1", YAYAP_GUI="1", YAYAP_ASK=helper, SUDO_ASKPASS=helper,
                   YAYAP_GUI_URL=f"http://127.0.0.1:{PORT}", YAYAP_GUI_TOKEN=TOKEN, YAYAP_GUI_JOB=self.id)
        self.lines.append("$ yayap " + " ".join(self.argv[2:]))
        try:
            self.proc = subprocess.Popen(self.argv, stdout=subprocess.PIPE, stderr=subprocess.STDOUT,
                                         stdin=subprocess.DEVNULL, env=env, text=True, bufsize=1,
                                         errors="replace",
                                         start_new_session=True)   # no controlling tty -> sudo uses askpass
            for line in self.proc.stdout:
                self.lines.append(ANSI.sub("", line.rstrip("\n")))
                if len(self.lines) > MAX_LINES:
                    del self.lines[1:len(self.lines) - MAX_LINES + 1]
            self.rc = self.proc.wait()
        except Exception as e:  # noqa: BLE001
            self.lines.append(f"error: {e}")
            self.rc = 1
        self.done = True

    def stop(self):
        if self.proc and self.proc.poll() is None:
            try:
                os.killpg(self.proc.pid, signal.SIGTERM)
            except ProcessLookupError:
                pass


def start_job(argv):
    job = Job(secrets.token_hex(6), argv)
    with JOBS_LOCK:
        JOBS[job.id] = job
    threading.Thread(target=job.run, args=(HELPER,), daemon=True).start()
    return job


def write_helper():
    """One helper for sudo -A (askpass), confirm() and ask_secret(): it asks the app and waits."""
    d = tempfile.mkdtemp(prefix="yayap-gui-")
    path = os.path.join(d, "ask")
    with open(path, "w") as f:
        f.write(f"""#!{sys.executable}
import json, os, sys, urllib.request
a = sys.argv[1:]
kind = "password"
if a and a[0] in ("--confirm", "--secret"):
    kind, a = a[0][2:], a[1:]
prompt = " ".join(a) or "Password"
req = urllib.request.Request(os.environ["YAYAP_GUI_URL"] + "/ask?job=" + os.environ.get("YAYAP_GUI_JOB", ""),
    data=json.dumps({{"kind": kind, "prompt": prompt}}).encode(),
    headers={{"X-YaYaP-Token": os.environ["YAYAP_GUI_TOKEN"], "Content-Type": "application/json"}})
try:
    with urllib.request.urlopen(req, timeout=900) as r:
        ans = json.load(r)
except Exception:
    sys.exit(1)
if ans.get("cancel"):
    sys.exit(1)
if kind != "confirm":
    sys.stdout.write(ans.get("value", "") + "\\n")
""")
    os.chmod(path, stat.S_IRWXU)
    return path


# ───────────────────────── http ─────────────────────────
class Handler(BaseHTTPRequestHandler):
    server_version = "yayap-gui"

    def log_message(self, *a):  # quiet
        pass

    def _send(self, code, obj, ctype="application/json"):
        body = obj if isinstance(obj, bytes) else json.dumps(obj).encode()
        self.send_response(code)
        self.send_header("Content-Type", ctype)
        self.send_header("Content-Length", str(len(body)))
        self.send_header("Cache-Control", "no-store")
        self.send_header("X-Content-Type-Options", "nosniff")
        self.send_header("Referrer-Policy", "no-referrer")
        self.end_headers()
        self.wfile.write(body)

    def _host_ok(self):
        # blocks DNS-rebinding: only our own loopback origin may talk to us
        return self.headers.get("Host", "") in (f"127.0.0.1:{PORT}", f"localhost:{PORT}")

    def _authed(self):
        return self._host_ok() and secrets.compare_digest(self.headers.get("X-YaYaP-Token", ""), TOKEN)

    def _body(self):
        n = int(self.headers.get("Content-Length") or 0)
        if n > 1_000_000:
            raise ValueError("too big")
        return json.loads(self.rfile.read(n) or b"{}")

    def do_GET(self):
        u = urlparse(self.path)
        q = parse_qs(u.query)
        if u.path == "/":
            if not self._host_ok() or not secrets.compare_digest((q.get("t") or [""])[0], TOKEN):
                return self._send(403, b"forbidden", "text/plain")
            with open(os.path.join(HERE, "index.html"), "rb") as f:
                html = f.read().replace(b"__TOKEN__", TOKEN.encode())
            return self._send(200, html, "text/html; charset=utf-8")
        if u.path in ("/yayap.svg", "/favicon.ico") and self._host_ok():   # the logo isn't secret
            with open(LOGO, "rb") as f:
                return self._send(200, f.read(), "image/svg+xml")
        if not self._authed():
            return self._send(403, {"error": "forbidden"})
        if u.path == "/api/tree":
            cats, _ = TREE
            return self._send(200, {"categories": cats, "host": os.uname().nodename,
                                    "user": pwd.getpwuid(os.getuid()).pw_name})
        if u.path == "/api/job":
            job = JOBS.get((q.get("id") or [""])[0])
            if not job:
                return self._send(404, {"error": "no such job"})
            since = int((q.get("since") or ["0"])[0] or 0)
            return self._send(200, {"lines": job.lines[since:], "next": len(job.lines),
                                    "done": job.done, "rc": job.rc, "ask": job.ask})
        return self._send(404, {"error": "not found"})

    def do_POST(self):
        u = urlparse(self.path)
        if not self._authed():
            return self._send(403, {"error": "forbidden"})
        try:
            body = self._body()
        except Exception:  # noqa: BLE001
            return self._send(400, {"error": "bad json"})
        LAST_PING[0] = time.time()
        if u.path == "/api/ping":
            return self._send(200, {"ok": True})
        if u.path == "/api/run":
            _, mods = TREE
            mod = mods.get(body.get("module"))
            if not mod:
                return self._send(400, {"error": "unknown module"})
            idx = body.get("action")
            try:
                if idx is None or idx == -1:
                    args = []
                else:
                    args = expand(mod["actions"][int(idx)]["template"], body.get("values") or [])
            except (ValueError, IndexError, TypeError) as e:
                return self._send(400, {"error": str(e)})
            job = start_job([YAYAP, "--no-color", mod["name"], *args])
            return self._send(200, {"job": job.id})
        if u.path == "/api/stop":
            job = JOBS.get(body.get("job"))
            if job:
                job.stop()
            return self._send(200, {"ok": True})
        if u.path == "/api/answer":
            job = JOBS.get(body.get("job"))
            if not job or not job.ask:
                return self._send(404, {"error": "nothing to answer"})
            job.answer = {"cancel": True} if body.get("cancel") else {"value": str(body.get("value", ""))}
            job.answered.set()
            return self._send(200, {"ok": True})
        if u.path == "/ask":   # from the helper; blocks until you answer in the app
            job = JOBS.get((parse_qs(u.query).get("job") or [""])[0])
            if not job:
                return self._send(404, {"cancel": True})
            kind = body.get("kind") if body.get("kind") in ("password", "secret", "confirm") else "password"
            job.answered.clear()
            job.answer = None
            job.ask = {"kind": kind, "prompt": str(body.get("prompt") or "Password").strip()[:300]}
            job.answered.wait(900)
            ans, job.ask, job.answer = job.answer or {"cancel": True}, None, None
            return self._send(200, ans)
        return self._send(404, {"error": "not found"})


# ───────────────────────── a real app window ─────────────────────────
def find_toolkit():
    """GTK WebKit → Qt WebEngine (first on KDE) → pywebview; None if nothing's there."""
    kde = "KDE" in os.environ.get("XDG_CURRENT_DESKTOP", "").upper()
    for tk in (["qt", "gtk", "pywebview"] if kde else ["gtk", "qt", "pywebview"]):
        try:
            if tk == "gtk":
                import gi
                gi.require_version("Gtk", "3.0")
                for v in ("4.1", "4.0"):
                    try:
                        gi.require_version("WebKit2", v)
                        break
                    except ValueError:
                        continue
                else:
                    raise ImportError("no WebKit2")
                from gi.repository import Gtk, WebKit2  # noqa: F401
                return "gtk"
            if tk == "qt":
                try:
                    from PyQt6.QtWebEngineWidgets import QWebEngineView  # noqa: F401
                    return "qt6"
                except ImportError:
                    from PySide6.QtWebEngineWidgets import QWebEngineView  # noqa: F401
                    return "pyside6"
            if tk == "pywebview":
                import webview  # noqa: F401
                return "pywebview"
        except Exception:  # noqa: BLE001 — missing bindings, no display…
            continue
    return None


def native_window(tk, url):
    title, w, h = "YaYaP Control Center", 1120, 760
    if tk == "gtk":
        import gi
        gi.require_version("Gtk", "3.0")
        from gi.repository import Gtk, WebKit2, GLib
        GLib.set_prgname("yayap")
        GLib.set_application_name(title)
        win = Gtk.Window(title=title)
        win.set_default_size(w, h)
        try:
            win.set_icon_from_file(LOGO)
        except Exception:  # noqa: BLE001 — no SVG loader, keep the theme icon
            win.set_icon_name("preferences-system")
        view = WebKit2.WebView()
        view.load_uri(url)
        win.add(view)
        win.connect("destroy", Gtk.main_quit)
        win.show_all()
        Gtk.main()
    elif tk in ("qt6", "pyside6"):
        if tk == "qt6":
            from PyQt6.QtWidgets import QApplication
            from PyQt6.QtWebEngineWidgets import QWebEngineView
            from PyQt6.QtCore import QUrl
            from PyQt6.QtGui import QIcon
        else:
            from PySide6.QtWidgets import QApplication
            from PySide6.QtWebEngineWidgets import QWebEngineView
            from PySide6.QtCore import QUrl
            from PySide6.QtGui import QIcon
        app = QApplication(["yayap"])
        app.setWindowIcon(QIcon(LOGO))
        app.setApplicationName(title)
        app.setDesktopFileName("yayap")
        view = QWebEngineView()
        view.setWindowTitle(title)
        view.resize(w, h)
        view.load(QUrl(url))
        view.show()
        app.exec()
    elif tk == "pywebview":
        import webview
        webview.create_window(title, url, width=w, height=h)
        webview.start()


def open_browser(url):
    for b in ("chromium", "chromium-browser", "google-chrome-stable", "google-chrome", "brave",
              "brave-browser", "microsoft-edge-stable", "vivaldi-stable"):
        if shutil.which(b):
            subprocess.Popen([b, f"--app={url}", "--window-size=1120,760", "--class=yayap"],
                             stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
            return True
    opener = shutil.which("xdg-open") or shutil.which("open")
    if opener:
        subprocess.Popen([opener, url], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL, start_new_session=True)
        return True
    return False


def watchdog(server):
    """Quit once the window has been gone for a while and nothing is running."""
    while True:
        time.sleep(5)
        busy = any(not j.done for j in list(JOBS.values()))
        if not busy and time.time() - LAST_PING[0] > 45:
            server.shutdown()
            return


def main():
    global YAYAP, PORT, TREE, HELPER
    ap = argparse.ArgumentParser(prog="yayap gui", description="YaYaP Control Center, as an app")
    ap.add_argument("--yayap", default=shutil.which("yayap") or "yayap", help=argparse.SUPPRESS)
    ap.add_argument("--no-window", action="store_true", help="don't open a window, just print the URL")
    ap.add_argument("--port", type=int, default=0, help="port on 127.0.0.1 (default: random)")
    a = ap.parse_args()

    YAYAP = a.yayap
    TREE = load_tree()
    HELPER = write_helper()
    server = ThreadingHTTPServer(("127.0.0.1", a.port), Handler)
    server.daemon_threads = True
    PORT = server.server_address[1]
    url = f"http://127.0.0.1:{PORT}/?t={TOKEN}"

    try:
        if a.no_window:
            print(url, flush=True)
            server.serve_forever()
            return
        tk = find_toolkit()
        if tk:
            threading.Thread(target=server.serve_forever, daemon=True).start()
            native_window(tk, url)          # blocks until the window closes
        else:
            if not open_browser(url):
                print(f"open this in your browser: {url}", flush=True)
            threading.Thread(target=watchdog, args=(server,), daemon=True).start()
            server.serve_forever()
    except KeyboardInterrupt:
        pass
    finally:
        for j in list(JOBS.values()):
            j.stop()
        shutil.rmtree(os.path.dirname(HELPER), ignore_errors=True)


if __name__ == "__main__":
    main()
