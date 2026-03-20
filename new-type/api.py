#!/usr/bin/env python3
"""
Shastra EV Dashboard — HTTP API Bridge
Reads latest_readings from SQLite and serves JSON + static frontend files.
"""

import json
import sqlite3
import os
from http.server import HTTPServer, SimpleHTTPRequestHandler

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Sensor_data.db")
FRONTEND_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "frontend")
PORT = 8080


class DashboardHandler(SimpleHTTPRequestHandler):
    """Serves the API endpoint and static frontend files."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=FRONTEND_DIR, **kwargs)

    def do_GET(self):
        if self.path == "/api/data":
            self._serve_sensor_data()
        else:
            super().do_GET()

    def _serve_sensor_data(self):
        try:
            conn = sqlite3.connect(DB_PATH)
            cursor = conn.cursor()
            cursor.execute("SELECT sensor_name, reading_value FROM latest_readings")
            rows = cursor.fetchall()
            conn.close()
            data = {row[0]: row[1] for row in rows}
        except Exception:
            data = {}

        payload = json.dumps(data)
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(payload.encode())

    def log_message(self, format, *args):
        # Quiet logging — only errors
        pass


if __name__ == "__main__":
    server = HTTPServer(("0.0.0.0", PORT), DashboardHandler)
    print(f"Shastra Dashboard running → http://localhost:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()
