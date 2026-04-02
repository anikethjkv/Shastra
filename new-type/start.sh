#!/bin/bash

# Navigate to the script's directory (new-type)
cd "$(dirname "$0")"

# Load optional local environment variables for backend services
# Priority: .env.local > .env
ENV_FILE=""
if [ -f ".env.local" ]; then
    ENV_FILE=".env.local"
elif [ -f ".env" ]; then
    ENV_FILE=".env"
fi

if [ -n "$ENV_FILE" ]; then
    echo "Loading environment from $ENV_FILE"
    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a
fi

echo "Cleaning up old processes..."
pkill -f "python3 Cancom.py"
pkill -f "python3 SensorReader.py"
pkill -f "python3 api.py"
pkill -f "convert_and_upload.py"
kill $(lsof -ti:8080) 2>/dev/null
sleep 1

echo "Opening terminals and starting Shastra Telemetry services..."

trigger_firebase_upload() {
    local upload_script="../CANCOM/convert_and_upload.py"
    local upload_log="firebase_upload.log"

    if [ "${RUN_FIREBASE_UPLOAD_ON_START:-0}" != "1" ]; then
        return
    fi

    if [ ! -f "$upload_script" ]; then
        echo "[warn] Firebase upload script not found at $upload_script"
        return
    fi

    if [ -z "${FIREBASE_SERVICE_ACCOUNT:-}" ] || [ -z "${FIREBASE_DATABASE_URL:-}" ]; then
        echo "[warn] RUN_FIREBASE_UPLOAD_ON_START=1 but Firebase env is missing"
        echo "       Required: FIREBASE_SERVICE_ACCOUNT and FIREBASE_DATABASE_URL"
        return
    fi

    SQLITE_DB_PATH="${SQLITE_DB_PATH:-$(pwd)/Sensor_data.db}" \
    FIREBASE_SERVICE_ACCOUNT="$FIREBASE_SERVICE_ACCOUNT" \
    FIREBASE_DATABASE_URL="$FIREBASE_DATABASE_URL" \
    FIREBASE_NODE="${FIREBASE_NODE:-sensor_data}" \
    nohup python3 "$upload_script" > "$upload_log" 2>&1 &

    echo "[ok] Triggered Firebase upload job -> $upload_log"
}

ensure_running() {
    local script="$1"
    local log_file="$2"

    if ! pgrep -f "$script" >/dev/null; then
        echo "[fallback] $script did not stay running. Starting in background..."
        nohup python3 "$script" > "$log_file" 2>&1 &
        sleep 0.5
    fi

    if pgrep -f "$script" >/dev/null; then
        echo "[ok] $script is running"
    else
        echo "[error] $script failed to start. Check $log_file"
    fi
}

# Raspberry Pi Default (LXDE Desktop)
if command -v lxterminal &> /dev/null; then
    lxterminal --title="CAN Telemetry" -e "python3 Cancom.py" &
    lxterminal --title="Sensor Reader" -e "python3 SensorReader.py" &
    lxterminal --title="API Server" -e "python3 api.py" &

# Secondary Debian Default Fallback
elif command -v x-terminal-emulator &> /dev/null; then
    x-terminal-emulator -T "CAN Telemetry" -e "python3 Cancom.py" &
    x-terminal-emulator -T "Sensor Reader" -e "python3 SensorReader.py" &
    x-terminal-emulator -T "API Server" -e "python3 api.py" &

# Basic X11 Fallback
elif command -v xterm &> /dev/null; then
    xterm -title "CAN Telemetry" -hold -e "python3 Cancom.py" &
    xterm -title "Sensor Reader" -hold -e "python3 SensorReader.py" &
    xterm -title "API Server" -hold -e "python3 api.py" &

# Mac OS fallback (if you test it on your Mac)
elif [[ "$OSTYPE" == "darwin"* ]]; then
    osascript -e 'tell app "Terminal" to do script "cd '\"$(pwd)\"' && python3 Cancom.py"'
    osascript -e 'tell app "Terminal" to do script "cd '\"$(pwd)\"' && python3 SensorReader.py"'
    osascript -e 'tell app "Terminal" to do script "cd '\"$(pwd)\"' && python3 api.py"'

# Headless / No GUI fallback
else
    echo "No GUI terminal found. Running in the background..."
    nohup python3 Cancom.py > cancom.log 2>&1 &
    nohup python3 SensorReader.py > sensorreader.log 2>&1 &
    nohup python3 api.py > api.log 2>&1 &
fi

sleep 1
ensure_running "Cancom.py" "cancom.log"
ensure_running "SensorReader.py" "sensorreader.log"
ensure_running "api.py" "api.log"
trigger_firebase_upload

echo "Done! The dashboard is running."
