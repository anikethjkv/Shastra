"""
Lightweight HTTP API server that bridges Sensor_data.db to the React frontend.
Exposes GET /api/telemetry → JSON of all latest sensor readings.
Run: python3 api_server.py
"""
import sqlite3
import json
from http.server import HTTPServer, BaseHTTPRequestHandler
from socketserver import ThreadingMixIn

DB_NAME = "Sensor_data.db"
HOST = "0.0.0.0"
PORT = 5050


def get_all_latest():
    """Read every row from latest_readings and return as {name: value} dict."""
    try:
        conn = sqlite3.connect(DB_NAME, timeout=2)
        conn.execute("PRAGMA journal_mode=WAL")      # Allow concurrent reads while writing
        conn.execute("PRAGMA read_uncommitted=ON")    # Don't wait for writer commits
        cursor = conn.cursor()
        cursor.execute("SELECT sensor_name, reading_value FROM latest_readings")
        rows = cursor.fetchall()
        conn.close()
        return {row[0]: row[1] for row in rows}
    except Exception:
        return {}


class APIHandler(BaseHTTPRequestHandler):
    """Minimal REST handler."""

    def do_GET(self):
        if self.path == "/api/telemetry":
            data = get_all_latest()
            body = json.dumps(data).encode()
            self.send_response(200)
            self.send_header("Content-Type", "application/json")
            self.send_header("Access-Control-Allow-Origin", "*")
            self.send_header("Cache-Control", "no-store, no-cache, must-revalidate")
            self.send_header("Pragma", "no-cache")
            self.send_header("Content-Length", str(len(body)))
            self.end_headers()
            self.wfile.write(body)
        else:
            self.send_error(404)

    def do_OPTIONS(self):
        """Handle CORS preflight."""
        self.send_response(204)
        self.send_header("Access-Control-Allow-Origin", "*")
        self.send_header("Access-Control-Allow-Methods", "GET, OPTIONS")
        self.send_header("Access-Control-Allow-Headers", "Content-Type")
        self.end_headers()

    def log_message(self, fmt, *args):
        pass


class ThreadedHTTPServer(ThreadingMixIn, HTTPServer):
    """Handle each request in a separate thread — prevents blocking."""
    daemon_threads = True


if __name__ == "__main__":
    server = ThreadedHTTPServer((HOST, PORT), APIHandler)
    print(f"API Server running on http://{HOST}:{PORT}/api/telemetry")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nAPI Server stopped.")
        server.server_close()
