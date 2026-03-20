#!/usr/bin/env python3
"""
Shastra EV Dashboard — HTTP API Bridge
Reads from SQLite + realtime file (/tmp/shastra_rt.json) for speed/RPM.
"""

import json
import sqlite3
import os
import datetime
from http.server import HTTPServer, SimpleHTTPRequestHandler

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Sensor_data.db")
FRONTEND_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "frontend")
RT_PATH = "/tmp/shastra_rt.json"
PORT = 8080


class DashboardHandler(SimpleHTTPRequestHandler):
    """Serves API endpoints and static frontend files."""

    def __init__(self, *args, **kwargs):
        super().__init__(*args, directory=FRONTEND_DIR, **kwargs)

    def do_GET(self):
        if self.path == "/api/data":
            self._serve_sensor_data()
        elif self.path == "/api/debug":
            self._serve_debug()
        else:
            super().do_GET()

    def _read_sqlite(self):
        """Read all values from SQLite latest_readings."""
        try:
            conn = sqlite3.connect(DB_PATH)
            cursor = conn.cursor()
            cursor.execute("SELECT sensor_name, reading_value FROM latest_readings")
            rows = cursor.fetchall()
            conn.close()
            return {row[0]: row[1] for row in rows}
        except:
            return {}

    def _read_realtime(self):
        """Read speed/RPM/power from tmpfs (fast path from Cancom.py)."""
        try:
            with open(RT_PATH, 'r') as f:
                rt = json.load(f)
            return {
                "vehicle_speed": rt.get("speed", 0),
                "motor_rpm": rt.get("rpm", 0),
                "motor_pwr": rt.get("pwr", 0),
            }
        except:
            return {}

    def _serve_sensor_data(self):
        # Merge SQLite data with realtime speed/RPM
        data = self._read_sqlite()
        data.update(self._read_realtime())  # RT values override SQLite

        payload = json.dumps(data)
        self.send_response(200)
        self.send_header("Content-Type", "application/json")
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Cache-Control", "no-cache")
        self.end_headers()
        self.wfile.write(payload.encode())

    def _serve_debug(self):
        """Debug: show all values + sources."""
        db = self._read_sqlite()
        rt = self._read_realtime()
        merged = {**db, **rt}
        info = {
            "server_time": datetime.datetime.now().isoformat(),
            "sqlite_count": len(db),
            "rt_keys": list(rt.keys()),
            "rt_values": rt,
            "all_values": merged,
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


class ReusableHTTPServer(HTTPServer):
    allow_reuse_address = True


if __name__ == "__main__":
    server = ReusableHTTPServer(("0.0.0.0", PORT), DashboardHandler)
    print(f"Shastra Dashboard running → http://localhost:{PORT}")
    print(f"  SQLite: {DB_PATH}")
    print(f"  RT file: {RT_PATH}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()
