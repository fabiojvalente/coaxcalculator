install-dev:
	pip3 install -r requirements.txt

generate-html:
	rm -f docs/index.html
	python3 genhtml.py

serve:
	python3 -m http.server --directory docs

# Serve docs/ and regenerate whenever the template (or cable data) changes.
serve-watch: generate-html
	@echo "Serving http://localhost:8000 — watching index.html.j2 and cables.yaml (Ctrl-C to stop)"
	@python3 -c "$$SERVE_WATCH_SCRIPT"

define SERVE_WATCH_SCRIPT
import http.server
import socketserver
import subprocess
import threading
import time
from pathlib import Path

PORT = 8000
paths = [Path("index.html.j2"), Path("cables.yaml")]

class Handler(http.server.SimpleHTTPRequestHandler):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory="docs", **kwargs)

    def log_message(self, format, *args):
        print(f"[http] {args[0]}")

httpd = socketserver.TCPServer(("", PORT), Handler)
httpd.allow_reuse_address = True
threading.Thread(target=httpd.serve_forever, daemon=True).start()

last = 0
try:
    while True:
        mtime = max(p.stat().st_mtime for p in paths)
        if mtime != last:
            last = mtime
            print("→ regenerating docs/index.html")
            subprocess.call(["make", "generate-html"])
        time.sleep(0.5)
except KeyboardInterrupt:
    print("\nStopping.")
finally:
    httpd.shutdown()
endef
export SERVE_WATCH_SCRIPT

docker:
	docker run --rm -it -v $(PWD):/app -p 8000:8000 python:3.8 bash -c "apt update && apt install -y make python3-pip && cd /app && make install-dev generate-html serve"
