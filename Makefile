install-dev:
	pip3 install -r requirements.txt

generate-html:
	rm -f docs/index.html
	python3 genhtml.py

serve:
	python3 -m http.server --directory docs

# Serve docs/ and regenerate whenever the template (or cable data) changes.
serve-watch: generate-html
	@echo "Serving http://localhost:8000 — watching index.html.j2, cables.yaml, locales.json (Ctrl-C to stop)"
	@exec python3 -c "$$SERVE_WATCH_SCRIPT"

define SERVE_WATCH_SCRIPT
import http.server
import signal
import socketserver
import subprocess
import sys
import threading
import time
from pathlib import Path

PORT = 8000
paths = [Path("index.html.j2"), Path("cables.yaml"), Path("locales.json")]

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory="docs", **kwargs)

    def log_message(self, format, *args):
        print(f"[http] {args[0]}")

class ReusableTCPServer(socketserver.TCPServer):
    allow_reuse_address = True

stop = threading.Event()

def _stop(*_):
    stop.set()

signal.signal(signal.SIGINT, _stop)
signal.signal(signal.SIGTERM, _stop)

httpd = ReusableTCPServer(("", PORT), Handler)
threading.Thread(target=httpd.serve_forever, daemon=True).start()

last = 0
try:
    while not stop.is_set():
        mtime = max(p.stat().st_mtime for p in paths)
        if mtime != last:
            last = mtime
            print("→ regenerating docs/index.html")
            # Call genhtml directly so nested make doesn't swallow Ctrl-C.
            subprocess.call([sys.executable, "genhtml.py"])
        stop.wait(0.5)
finally:
    print("\nStopping.")
    httpd.shutdown()
    httpd.server_close()
endef
export SERVE_WATCH_SCRIPT

docker:
	docker run --rm -it -v $(PWD):/app -p 8000:8000 python:3.8 bash -c "apt update && apt install -y make python3-pip && cd /app && make install-dev generate-html serve"
