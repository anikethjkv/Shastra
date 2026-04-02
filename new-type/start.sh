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

START_CANCOM=1
START_SENSOR=1
START_API=1
API_ALREADY_RUNNING=0

preflight_checks() {
    if ! python3 -c "import can" >/dev/null 2>&1; then
        echo "[error] Missing Python dependency for Cancom.py: python-can"
        echo "        Install with: python3 -m pip install python-can"
        START_CANCOM=0
    fi

    local api_port_pid
    api_port_pid="$(lsof -ti:8080 2>/dev/null | head -n 1)"
    if [ -n "$api_port_pid" ]; then
        local api_port_cmd
        api_port_cmd="$(ps -p "$api_port_pid" -o command= 2>/dev/null)"
        if echo "$api_port_cmd" | grep -q "api.py"; then
            echo "[info] api.py is already running on port 8080 (pid $api_port_pid)"
            API_ALREADY_RUNNING=1
            START_API=0
        else
            echo "[warn] Port 8080 is already in use by: ${api_port_cmd:-unknown process}"
            echo "       Skipping api.py startup to avoid crash."
            START_API=0
        fi
    fi
}

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

preflight_checks

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
    if [ "$START_CANCOM" = "1" ]; then lxterminal --title="CAN Telemetry" -e "python3 Cancom.py" & fi
    if [ "$START_SENSOR" = "1" ]; then lxterminal --title="Sensor Reader" -e "python3 SensorReader.py" & fi
    if [ "$START_API" = "1" ]; then lxterminal --title="API Server" -e "python3 api.py" & fi

# Secondary Debian Default Fallback
elif command -v x-terminal-emulator &> /dev/null; then
    if [ "$START_CANCOM" = "1" ]; then x-terminal-emulator -T "CAN Telemetry" -e "python3 Cancom.py" & fi
    if [ "$START_SENSOR" = "1" ]; then x-terminal-emulator -T "Sensor Reader" -e "python3 SensorReader.py" & fi
    if [ "$START_API" = "1" ]; then x-terminal-emulator -T "API Server" -e "python3 api.py" & fi

# Basic X11 Fallback
elif command -v xterm &> /dev/null; then
    if [ "$START_CANCOM" = "1" ]; then xterm -title "CAN Telemetry" -hold -e "python3 Cancom.py" & fi
    if [ "$START_SENSOR" = "1" ]; then xterm -title "Sensor Reader" -hold -e "python3 SensorReader.py" & fi
    if [ "$START_API" = "1" ]; then xterm -title "API Server" -hold -e "python3 api.py" & fi

# Mac OS fallback (if you test it on your Mac)
elif [[ "$OSTYPE" == "darwin"* ]]; then
    if [ "$START_CANCOM" = "1" ]; then osascript -e "tell app \"Terminal\" to do script \"cd '$PWD' && python3 Cancom.py\""; fi
    if [ "$START_SENSOR" = "1" ]; then osascript -e "tell app \"Terminal\" to do script \"cd '$PWD' && python3 SensorReader.py\""; fi
    if [ "$START_API" = "1" ]; then osascript -e "tell app \"Terminal\" to do script \"cd '$PWD' && python3 api.py\""; fi

# Headless / No GUI fallback
else
    echo "No GUI terminal found. Running in the background..."
    if [ "$START_CANCOM" = "1" ]; then nohup python3 Cancom.py > cancom.log 2>&1 & fi
    if [ "$START_SENSOR" = "1" ]; then nohup python3 SensorReader.py > sensorreader.log 2>&1 & fi
    if [ "$START_API" = "1" ]; then nohup python3 api.py > api.log 2>&1 & fi
fi

sleep 1
if [ "$START_CANCOM" = "1" ]; then
    ensure_running "Cancom.py" "cancom.log"
else
    echo "[skip] Cancom.py startup skipped due to failed preflight checks"
fi

if [ "$START_SENSOR" = "1" ]; then
    ensure_running "SensorReader.py" "sensorreader.log"
else
    echo "[skip] SensorReader.py startup skipped"
fi

if [ "$START_API" = "1" ]; then
    ensure_running "api.py" "api.log"
elif [ "$API_ALREADY_RUNNING" = "1" ]; then
    echo "[ok] api.py is already running"
else
    echo "[skip] api.py startup skipped because port 8080 is busy"
fi
trigger_firebase_upload

echo "Done! The dashboard is running."
