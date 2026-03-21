#!/usr/bin/env python3
"""
Shastra EV Dashboard — HTTP API Bridge
Reads latest_readings from SQLite and serves JSON + static frontend files.
"""

import json
import sqlite3
import os
import datetime
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
import time

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Sensor_data.db")
FRONTEND_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "frontend")
PORT = 8080


class DashboardHandler(SimpleHTTPRequestHandler):
    """Serves API endpoints and static frontend files."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=FRONTEND_DIR, **kwargs)

    def do_GET(self):
        if self.path == "/api/data":
            self._serve_sensor_data()
        elif self.path == "/api/stream":
            self._serve_sse()
        elif self.path == "/api/debug":
            self._serve_debug()
        else:
            super().do_GET()

    def _get_db_data(self):
        try:
            conn = sqlite3.connect(DB_PATH)
            cursor = conn.cursor()
            cursor.execute("SELECT sensor_name, reading_value FROM latest_readings")
            rows = cursor.fetchall()
            conn.close()
            return {row[0]: row[1] for row in rows}
        except:
            return {}

    def _serve_sensor_data(self):
        data = self._get_db_data()
        payload = json.dumps(data)
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(payload.encode())

    def _serve_sse(self):
        """Server-Sent Events: push data continuously without polling overhead."""
        self.send_response(200)
        self.send_header('Content-Type', 'text/event-stream')
        self.send_header('Cache-Control', 'no-cache')
        self.send_header('Connection', 'keep-alive')
        self.send_header('Access-Control-Allow-Origin', '*')
        self.end_headers()

        while True:
            try:
                data = self._get_db_data()
                payload = json.dumps(data)
                self.wfile.write(f"data: {payload}\n\n".encode())
                self.wfile.flush()
                time.sleep(0.05)  # 20 FPS updates
            except Exception:
                # Connection closed by client
                break

    def _serve_debug(self):
        data = self._get_db_data()
        info = {
            "server_time": datetime.datetime.now().isoformat(),
            "count": len(data),
            "values": data,
        }
        payload = json.dumps(info, indent=2)
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(payload.encode())

    def log_message(self, format, *args):
        pass


class ReusableThreadingHTTPServer(ThreadingHTTPServer):
    allow_reuse_address = True


if __name__ == "__main__":
    server = ReusableThreadingHTTPServer(("0.0.0.0", PORT), DashboardHandler)
    print(f"Shastra Dashboard running → http://localhost:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()
