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
import threading

from firebase_sync import sync_sqlite_to_firebase

DB_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "Sensor_data.db")
FRONTEND_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "frontend")
PORT = 8080
FIREBASE_SERVICE_ACCOUNT = os.environ.get("FIREBASE_SERVICE_ACCOUNT", "").strip()
FIREBASE_DATABASE_URL = os.environ.get("FIREBASE_DATABASE_URL", "").strip()
FIREBASE_NODE = os.environ.get("FIREBASE_NODE", "sensor_data").strip() or "sensor_data"
FIREBASE_SYNC_INTERVAL_SEC = max(0, int(os.environ.get("FIREBASE_SYNC_INTERVAL_SEC", "60") or 60))


def firebase_sync_configured() -> bool:
    return bool(FIREBASE_SERVICE_ACCOUNT and FIREBASE_DATABASE_URL)


def run_periodic_firebase_sync():
    if not firebase_sync_configured() or FIREBASE_SYNC_INTERVAL_SEC <= 0:
        return

    while True:
        try:
            result = sync_sqlite_to_firebase(
                db_path=DB_PATH,
                service_account_path=FIREBASE_SERVICE_ACCOUNT,
                database_url=FIREBASE_DATABASE_URL,
                node=FIREBASE_NODE,
            )
            print(f"[firebase-sync] ok tables={result.get('tables', 0)} node={FIREBASE_NODE}")
        except Exception as exc:
            print(f"[firebase-sync] error: {exc}")
        time.sleep(FIREBASE_SYNC_INTERVAL_SEC)


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
        elif self.path == "/api/upload/firebase":
            self._serve_firebase_upload()
        else:
            super().do_GET()

    def do_POST(self):
        if self.path == "/api/upload/firebase":
            self._serve_firebase_upload()
            return
        self.send_response(404)
        self.end_headers()

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

    def _serve_firebase_upload(self):
        if not firebase_sync_configured():
            payload = json.dumps(
                {
                    "ok": False,
                    "error": "Missing Firebase config",
                    "required_env": ["FIREBASE_SERVICE_ACCOUNT", "FIREBASE_DATABASE_URL"],
                }
            )
            self.send_response(400)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(payload.encode())
            return

        try:
            result = sync_sqlite_to_firebase(
                db_path=DB_PATH,
                service_account_path=FIREBASE_SERVICE_ACCOUNT,
                database_url=FIREBASE_DATABASE_URL,
                node=FIREBASE_NODE,
            )
            payload = json.dumps({"ok": True, "result": result})
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.end_headers()
            self.wfile.write(payload.encode())
        except Exception as exc:
            payload = json.dumps({"ok": False, "error": str(exc)})
            self.send_response(500)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
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

        # Keep connection open for blazing fast reads, isolation_level=None prevents stale snapshots
        try:
            conn = sqlite3.connect(DB_PATH, isolation_level=None)
            conn.execute("PRAGMA journal_mode=WAL")
        except:
            return

        while True:
            try:
                cursor = conn.cursor()
                cursor.execute("SELECT sensor_name, reading_value FROM latest_readings")
                data = {row[0]: row[1] for row in cursor.fetchall()}
                
                payload = json.dumps(data)
                self.wfile.write(f"data: {payload}\n\n".encode())
                self.wfile.flush()
                time.sleep(0.02)  # 50 FPS updates
            except Exception:
                break
        
        conn.close()

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
    if firebase_sync_configured() and FIREBASE_SYNC_INTERVAL_SEC > 0:
        sync_thread = threading.Thread(target=run_periodic_firebase_sync, daemon=True)
        sync_thread.start()
        print(f"[firebase-sync] periodic upload enabled every {FIREBASE_SYNC_INTERVAL_SEC}s")
    elif firebase_sync_configured():
        print("[firebase-sync] periodic upload disabled (FIREBASE_SYNC_INTERVAL_SEC <= 0)")
    else:
        print("[firebase-sync] not configured; set FIREBASE_SERVICE_ACCOUNT and FIREBASE_DATABASE_URL")

    server = ReusableThreadingHTTPServer(("0.0.0.0", PORT), DashboardHandler)
    print(f"Shastra Dashboard running → http://localhost:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()
