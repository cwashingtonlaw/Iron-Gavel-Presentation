#!/usr/bin/env python3
"""
serve.py — local server for the Iron Gavel / Courtroom Justice app
==================================================================
Serves the trial-presentation app and a case's Trial/ directory over HTTP so
that exhibits.json and its relative exhibit files resolve correctly in the
browser. Read-only: this server never writes case data.

Layout it exposes:
    /                      -> redirect to /app/index.html (operator console)
    /app/...               -> the bundled web app (this repo's app/ folder)
    /Trial/exhibits.json   -> the sidecar, from the chosen case root
    /Trial/<exhibit file>  -> exhibit media, from the chosen case root
    everything else        -> served from the case root

By default the case root is this repository (so the bundled sample case in
./Trial runs out of the box). Point at a real case with --case-root:

    python3 serve.py
    python3 serve.py --case-root "/path/to/CASE_ROOT" --port 8000

Then open the operator console it prints, and click "Open Jury Display" for the
second monitor.
"""

import argparse
import functools
import http.server
import os
import socketserver
import sys
import webbrowser

HERE = os.path.dirname(os.path.abspath(__file__))
APP_DIR = os.path.join(HERE, "app")


class Handler(http.server.SimpleHTTPRequestHandler):
    """Routes /app/* to the app folder and everything else to the case root."""

    app_dir = APP_DIR
    case_root = HERE

    def translate_path(self, path):
        # Strip query/fragment and leading slash.
        clean = path.split("?", 1)[0].split("#", 1)[0].lstrip("/")
        if clean == "app" or clean.startswith("app/"):
            base = self.app_dir
            rel = clean[len("app/"):] if clean.startswith("app/") else ""
            if rel == "":
                rel = "index.html"
        else:
            base = self.case_root
            rel = clean
        # Prevent path escapes outside the chosen base.
        full = os.path.normpath(os.path.join(base, rel))
        if full != base and not full.startswith(base + os.sep):
            return base
        return full

    def do_GET(self):
        if self.path in ("/", ""):
            self.send_response(302)
            self.send_header("Location", "/app/index.html")
            self.end_headers()
            return
        super().do_GET()

    def end_headers(self):
        # Courtroom use is offline/local; keep the browser from caching a stale
        # sidecar between reloads.
        self.send_header("Cache-Control", "no-store")
        super().end_headers()

    def log_message(self, fmt, *args):
        sys.stderr.write("  " + (fmt % args) + "\n")


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("--case-root", default=HERE,
                    help="Folder that contains Trial/exhibits.json (default: this repo's sample case).")
    ap.add_argument("--port", type=int, default=8000)
    ap.add_argument("--host", default="127.0.0.1")
    ap.add_argument("--no-open", action="store_true", help="Do not auto-open a browser.")
    args = ap.parse_args()

    case_root = os.path.abspath(args.case_root)
    sidecar = os.path.join(case_root, "Trial", "exhibits.json")
    if not os.path.isfile(sidecar):
        print("WARNING: no sidecar found at %s" % sidecar, file=sys.stderr)
        print("         The app will show a load error until the exhibit skill emits it.", file=sys.stderr)

    Handler.app_dir = APP_DIR
    Handler.case_root = case_root

    socketserver.TCPServer.allow_reuse_address = True
    httpd = socketserver.ThreadingTCPServer((args.host, args.port), Handler)
    url = "http://%s:%d/app/index.html" % (args.host, args.port)
    print("Iron Gavel — Courtroom Justice")
    print("  case root : %s" % case_root)
    print("  sidecar   : %s" % sidecar)
    print("  operator  : %s" % url)
    print("  (Ctrl+C to stop)")
    if not args.no_open:
        try:
            webbrowser.open(url)
        except Exception:
            pass
    try:
        httpd.serve_forever()
    except KeyboardInterrupt:
        print("\nstopped.")
        httpd.shutdown()


if __name__ == "__main__":
    main()
