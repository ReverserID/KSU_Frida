#!/usr/bin/env python3
"""Package module/ into a flashable KernelSU zip and/or validate it.

Usage:
    python tools/package.py           build dist/frida-ksu-<ver>.zip
    python tools/package.py --check   validate only (prop, sh syntax,
                                      zip exec bits, asset URLs reachable)
"""
import os
import re
import subprocess
import sys
import urllib.request
import zipfile

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
MOD = os.path.join(ROOT, "module")
DIST = os.path.join(ROOT, "dist")

EXEC = {"customize.sh", "service.sh", "action.sh", "uninstall.sh",
        "system/bin/frida-server"}
ID_RE = re.compile(r"^[a-zA-Z][a-zA-Z0-9._-]+$")
ARCHES = ("arm", "arm64", "x86", "x86_64")


def read_prop():
    d = {}
    with open(os.path.join(MOD, "module.prop"), "rb") as f:
        raw = f.read()
    assert b"\r" not in raw, "module.prop must use LF line endings"
    for line in raw.decode().splitlines():
        if "=" in line:
            k, v = line.split("=", 1)
            d[k.strip()] = v.strip()
    return d


def version_from_prop(prop):
    return prop["version"].lstrip("v")


def check(prop):
    errors = []
    if not ID_RE.match(prop.get("id", "")):
        errors.append(f"bad id: {prop.get('id')!r}")
    try:
        int(prop["versionCode"])
    except (KeyError, ValueError):
        errors.append("versionCode must be an integer")
    for key in ("name", "version", "author", "description"):
        if not prop.get(key):
            errors.append(f"module.prop missing {key}")
    for fn in ("customize.sh", "service.sh", "action.sh", "uninstall.sh",
               "lib.sh", "sepolicy.rule", "module.prop", "listen_addr",
               "banner.txt",
               "webroot/index.html",
               "webroot/icon.png"):
        p = os.path.join(MOD, fn)
        if not os.path.isfile(p):
            errors.append(f"missing {fn}")
        elif fn.endswith(".sh") and b"\r" in open(p, "rb").read():
            errors.append(f"{fn} has CRLF (must be LF)")
    for fn in ("customize.sh", "service.sh", "action.sh", "uninstall.sh",
               "lib.sh"):
        p = os.path.join(MOD, fn)
        r = subprocess.run(["sh", "-n", p], capture_output=True, text=True)
        if r.returncode != 0:
            errors.append(f"{fn} syntax: {r.stderr.strip()}")
    return errors


def check_urls(ver):
    bad = []
    for arch in ARCHES:
        url = (f"https://github.com/frida/frida/releases/download/{ver}/"
               f"frida-server-{ver}-android-{arch}.xz")
        req = urllib.request.Request(url, method="HEAD")
        try:
            with urllib.request.urlopen(req, timeout=20) as r:
                if r.status != 200:
                    bad.append(f"{arch}: HTTP {r.status}")
                else:
                    print(f"  {arch}: OK "
                          f"({r.headers.get('Content-Length', '?')} bytes)")
        except Exception as e:  # noqa: BLE001
            bad.append(f"{arch}: {e}")
    return bad


def build(prop):
    ver = version_from_prop(prop)
    os.makedirs(DIST, exist_ok=True)
    out = os.path.join(DIST, f"frida-ksu-{ver}.zip")
    names = []
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for dirpath, _dirs, files in os.walk(MOD):
            for fn in sorted(files):
                full = os.path.join(dirpath, fn)
                rel = os.path.relpath(full, MOD).replace(os.sep, "/")
                if os.path.getsize(full) == 0 and fn == "frida-server":
                    continue  # never ship a placeholder binary
                mode = 0o755 if fn in EXEC or rel in EXEC else 0o644
                zi = zipfile.ZipInfo(rel)
                zi.external_attr = (mode << 16)
                with open(full, "rb") as f:
                    z.writestr(zi, f.read())
                names.append(f"{oct(mode)} {rel}")
    print(f"wrote {out} ({os.path.getsize(out)} bytes)")
    for n in names:
        print(f"  {n}")
    return out


def main():
    prop = read_prop()
    print(f"module {prop.get('id')} version={prop.get('version')} "
          f"versionCode={prop.get('versionCode')}")
    errors = check(prop)
    ver = version_from_prop(prop)
    print("checking upstream asset URLs...")
    errors += check_urls(ver)
    if errors:
        print("FAILED:")
        for e in errors:
            print(f"  - {e}")
        return 1
    if "--check" in sys.argv:
        print("CHECK OK")
        return 0
    build(prop)
    print("BUILD OK")
    return 0


if __name__ == "__main__":
    sys.exit(main())
