#!/usr/bin/env python3
"""Three Against One — 开发路线图 本地服务器"""

import json, os, sys
from http.server import HTTPServer, SimpleHTTPRequestHandler
from urllib.parse import urlparse

PORT = 8080
STATE_FILE = os.path.join(os.path.dirname(__file__), "state.json")


class Handler(SimpleHTTPRequestHandler):
    def do_GET(self):
        if self.path == "/api/state":
            self._send_json(self._load_state())
        else:
            super().do_GET()

    def do_POST(self):
        if self.path == "/api/state":
            length = int(self.headers.get("Content-Length", 0))
            body = self.rfile.read(length)
            data = json.loads(body)
            with open(STATE_FILE, "w", encoding="utf-8") as f:
                json.dump(data, f, ensure_ascii=False, indent=2)
            self._send_json({"ok": True})
        else:
            self.send_response(404)
            self.end_headers()

    def _send_json(self, obj):
        payload = json.dumps(obj, ensure_ascii=False).encode("utf-8")
        self.send_response(200)
        self.send_header("Content-Type", "application/json; charset=utf-8")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.end_headers()
        self.wfile.write(payload)

    def _load_state(self):
        if os.path.exists(STATE_FILE):
            try:
                with open(STATE_FILE, "r", encoding="utf-8") as f:
                    return json.load(f)
            except Exception:
                return {"modules": {}}
        return {"modules": {}}

    def log_message(self, format, *args):
        print(f"[server] {args[0]} {args[1]} {args[2]}")


if __name__ == "__main__":
    os.chdir(os.path.dirname(__file__))
    server = HTTPServer(("0.0.0.0", PORT), Handler)
    print(f"[server] 开发路线图服务启动 → http://localhost:{PORT}")
    print(f"[server] 按 Ctrl+C 停止")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\n[server] 服务已停止")
        server.server_close()
