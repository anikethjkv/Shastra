#!/bin/bash
# Shastra Dashboard — Launch all services
# Usage: ./start.sh

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
NEW_TYPE="$SCRIPT_DIR/new-type"
FRONTEND="$SCRIPT_DIR/frontend"

cleanup() {
    echo ""
    echo "🛑 Stopping all services..."
    kill $PID_SQL $PID_CAN $PID_API $PID_ELECTRON 2>/dev/null
    wait 2>/dev/null
    echo "Done."
    exit 0
}
trap cleanup INT TERM

echo "🚀 Starting Shastra Dashboard..."

# 1. SQL Writer (must run from new-type/ for Sensor_data.db path)
echo "[1/4] Starting sqlwriter..."
cd "$NEW_TYPE" && python3 sqlwriter.py &
PID_SQL=$!
sleep 2

# 2. CAN Collector
echo "[2/4] Starting Cancom..."
cd "$NEW_TYPE" && python3 Cancom.py &
PID_CAN=$!
sleep 1

# 3. API Server
echo "[3/4] Starting API server..."
cd "$NEW_TYPE" && python3 api_server.py &
PID_API=$!
sleep 1

# 4. Electron Dashboard (suppress GPU error spam, force software rendering)
echo "[4/4] Starting Electron dashboard..."
cd "$FRONTEND" && ELECTRON_DISABLE_SANDBOX=1 npx electron . \
    --disable-gpu \
    --disable-software-rasterizer \
    --no-sandbox \
    --disable-dev-shm-usage \
    2>/dev/null &
PID_ELECTRON=$!

echo ""
echo "✅ All services running!"
echo "   sqlwriter   PID: $PID_SQL"
echo "   Cancom      PID: $PID_CAN"
echo "   API server  PID: $PID_API"
echo "   Electron    PID: $PID_ELECTRON"
echo ""
echo "Press Ctrl+C to stop all services."

# Wait for any process to exit
wait
