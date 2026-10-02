#!/usr/bin/env python3
"""Tests for the GUI server: auth, the module tree, running jobs, dialogs, stop.
Usage: tests/gui_test.py   (exit status 0 = all good)"""
import json, os, subprocess, sys, time, urllib.error, urllib.request

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
proc = subprocess.Popen([os.path.join(ROOT, "bin", "yayap"), "gui", "--no-window"],
                        stdout=subprocess.PIPE, text=True, start_new_session=True)
url = proc.stdout.readline().strip()
base, token = url.split("/?t=")
fails = 0


def call(path, body=None, token=token, host=None):
    headers = {"Content-Type": "application/json"}
    if token:
        headers["X-YaYaP-Token"] = token
    if host:
        headers["Host"] = host
    req = urllib.request.Request(base + path, headers=headers,
                                 data=None if body is None else json.dumps(body).encode())
    try:
        with urllib.request.urlopen(req, timeout=10) as r:
            return r.status, r.read()
    except urllib.error.HTTPError as e:
        return e.code, e.read()


def wait_job(jid, until=lambda d: d["done"], timeout=10):
    end = time.time() + timeout
    while time.time() < end:
        d = json.loads(call(f"/api/job?id={jid}")[1])
        if until(d):
            return d
        time.sleep(0.2)
    raise TimeoutError(jid)


def t(name, fn):
    global fails
    try:
        ok = fn()
    except Exception as e:  # noqa: BLE001
        ok, name = False, f"{name} ({e!r})"
    print(("ok   " if ok else "FAIL ") + "gui: " + name)
    fails += 0 if ok else 1


def run(module, action=None, values=None):
    s, b = call("/api/run", {"module": module, "action": action, "values": values or []})
    return s, json.loads(b)


try:
    t("page needs token", lambda: call("/", token=None)[0] == 403)
    t("page with token", lambda: urllib.request.urlopen(url, timeout=5).status == 200)
    t("logo is served", lambda: call("/yayap.svg", token=None)[1].startswith(b"<svg"))
    t("logo needs our Host", lambda: call("/yayap.svg", token=None, host="evil.example")[0] == 403)
    t("api needs token", lambda: call("/api/tree", token=None)[0] == 403)
    t("api wrong token", lambda: call("/api/tree", token="nope")[0] == 403)
    t("api rejects foreign Host", lambda: call("/api/tree", host="evil.example")[0] == 403)

    tree = json.loads(call("/api/tree")[1])
    cats = [c["name"] for c in tree["categories"]]
    t("tree has YaST categories", lambda: cats[:2] == ["Software", "System"] and "Security and Users" in cats)
    mods = {m["name"]: m for c in tree["categories"] for m in c["modules"]}
    t("tree has actions + fields", lambda: mods["passgen"]["actions"][3]["fields"][0]["prompt"] == "Length")
    t("tree has icons", lambda: mods["pkg"]["icon"] == "📦")

    t("unknown module refused", lambda: run("../../bin/sh")[0] == 400)
    t("empty value refused", lambda: run("passgen", 3, [""])[0] == 400)
    t("missing value refused", lambda: run("passgen", 3, [])[0] == 400)

    def passgen():
        s, j = run("passgen", 3, ["17"])
        d = wait_job(j["job"])
        return s == 200 and d["rc"] == 0 and len(d["lines"][-1]) == 17 and d["lines"][0] == "$ yayap passgen -l 17"
    t("run a module action", passgen)

    def no_actions():
        d = wait_job(run("yap")[1]["job"])
        return d["rc"] == 0 and any("(oo)" in l for l in d["lines"])
    t("run a module without actions", no_actions)

    def confirm_cancel():   # clean --force asks first; saying no must not delete anything
        j = run("clean", 1)[1]["job"]
        d = wait_job(j, until=lambda d: d["ask"] or d["done"])
        asked = d["ask"] and d["ask"]["kind"] == "confirm"
        call("/api/answer", {"job": j, "cancel": True})
        return asked and wait_job(j)["rc"] != 0
    t("confirm dialog + cancel", confirm_cancel)

    def stop():
        j = run("serve", 1, ["/", "0"])[1]["job"]   # port 0: any free port
        time.sleep(1)
        call("/api/stop", {"job": j})
        return wait_job(j)["done"]
    t("stop a running job", stop)
finally:
    os.killpg(proc.pid, 15)

print(f"gui: {fails} failed")
sys.exit(1 if fails else 0)
