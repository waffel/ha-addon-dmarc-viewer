"""Test double for the viewer API and the Home Assistant states API.

Usage: python3 mock_server.py <dir>
- GET /summary serves <dir>/summary.json, GET /dmarc-reports serves <dir>/reports.json, anything else is a 404.
- If <dir>/auth.expected exists, GET requests must carry exactly that Authorization header, otherwise 401.
- Every GET path is appended to <dir>/requests.log.
- Every POST is appended to <dir>/posts.jsonl as {"path", "auth", "body"}.
"""
import json
import os
import sys
from http.server import BaseHTTPRequestHandler, HTTPServer

DIRECTORY = sys.argv[1]
FILES = {"/summary": "summary.json", "/dmarc-reports": "reports.json"}


class Handler(BaseHTTPRequestHandler):
    def _reply(self, text, status=200):
        data = text.encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(data)))
        self.end_headers()
        self.wfile.write(data)

    def do_GET(self):
        with open(f"{DIRECTORY}/requests.log", "a") as f:
            f.write(self.path + "\n")
        expected_file = f"{DIRECTORY}/auth.expected"
        if os.path.exists(expected_file):
            with open(expected_file) as f:
                if self.headers.get("Authorization", "") != f.read().strip():
                    return self._reply("{}", 401)
        if self.path not in FILES:
            return self._reply("{}", 404)
        with open(f"{DIRECTORY}/{FILES[self.path]}") as f:
            self._reply(f.read())

    def do_POST(self):
        body = json.loads(self.rfile.read(int(self.headers["Content-Length"])))
        entry = {"path": self.path, "auth": self.headers.get("Authorization", ""), "body": body}
        with open(f"{DIRECTORY}/posts.jsonl", "a") as f:
            f.write(json.dumps(entry) + "\n")
        self._reply("{}")

    def log_message(self, *args):
        pass


HTTPServer(("127.0.0.1", 9000), Handler).serve_forever()
