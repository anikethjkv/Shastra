#!/bin/bash
# Shastra Dashboard — Launch all services
# Usage: ./start.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEW_TYPE="$SCRIPT_DIR/new-type"
FRONTEND="$SCRIPT_DIR/frontend"

echo "🚀 Starting Shastra Dashboard..."

# 1. SQL Writer (ZMQ → SQLite)
echo "[1/4] Starting sqlwriter..."
python3 "$NEW_TYPE/sqlwriter.py" &
PID_SQL=$!
sleep 1

# 2. CAN Collector (CAN bus → ZMQ)
echo "[2/4] Starting Cancom..."
python3 "$NEW_TYPE/Cancom.py" &
PID_CAN=$!
sleep 1

# 3. API Server (SQLite → HTTP)
echo "[3/4] Starting API server..."
python3 "$NEW_TYPE/api_server.py" &
PID_API=$!
sleep 1

# 4. Electron Dashboard
echo "[4/4] Starting Electron dashboard..."
cd "$FRONTEND" && npm run electron:start &
PID_ELECTRON=$!

echo ""
echo "✅ All services running!"
echo "   sqlwriter   PID: $PID_SQL"
echo "   Cancom      PID: $PID_CAN"
echo "   API server  PID: $PID_API"
echo "   Electron    PID: $PID_ELECTRON"
echo ""
echo "Press Ctrl+C to stop all services."

# Trap Ctrl+C to kill all background processes
cleanup() {
    echo ""
    echo "🛑 Stopping all services..."
    kill $PID_ELECTRON $PID_API $PID_CAN $PID_SQL 2>/dev/null
    wait 2>/dev/null
    echo "Done."
}
trap cleanup INT TERM

# Wait for any process to exit
wait
