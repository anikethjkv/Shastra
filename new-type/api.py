#!/usr/bin/env python3
"""
Shastra EV Dashboard — HTTP API Bridge
Receives live CAN telemetry from localhost UDP and serves JSON + static frontend files.
"""

import json
import os
import datetime
from http.server import ThreadingHTTPServer, SimpleHTTPRequestHandler
import time
import socket
import threading

BASE_DIR = os.path.dirname(os.path.abspath(__file__))
FRONTEND_DIR = os.path.join(os.path.dirname(os.path.abspath(__file__)), "frontend")
PORT = 8080
UDP_LISTEN_HOST = "127.0.0.1"
UDP_LISTEN_PORT = 8765

latest_state = {}
latest_state_lock = threading.Lock()


def read_state_snapshot():
    with latest_state_lock:
        return dict(latest_state)


def udp_listener_loop():
    sock = socket.socket(socket.AF_INET, socket.SOCK_DGRAM)
    sock.bind((UDP_LISTEN_HOST, UDP_LISTEN_PORT))
    while True:
        try:
            payload, _ = sock.recvfrom(65535)
            decoded = json.loads(payload.decode("utf-8"))
            if not isinstance(decoded, dict):
                continue
            sanitized = {}
            for k, v in decoded.items():
                if isinstance(k, str) and isinstance(v, (int, float)):
                    sanitized[k] = float(v)
            if sanitized:
                with latest_state_lock:
                    latest_state.update(sanitized)
        except Exception:
            continue


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

    def do_POST(self):
        self.send_response(404)
        self.end_headers()

    def _serve_sensor_data(self):
        data = read_state_snapshot()
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
                data = read_state_snapshot()
                payload = json.dumps(data)
                self.wfile.write(f"data: {payload}\n\n".encode())
                self.wfile.flush()
                time.sleep(0.05)  # 20 FPS updates
            except Exception:
                break

    def _serve_debug(self):
        data = read_state_snapshot()
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
    listener = threading.Thread(target=udp_listener_loop, daemon=True)
    listener.start()
    server = ReusableThreadingHTTPServer((
        "0.0.0.0", PORT), DashboardHandler)
    print(f"Shastra Dashboard running → http://localhost:{PORT}")
    try:
        server.serve_forever()
    except KeyboardInterrupt:
        print("\nShutting down.")
        server.server_close()
