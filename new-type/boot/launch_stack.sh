#!/bin/bash
set -euo pipefail

WORKDIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$WORKDIR"

# Load env vars if present (.env.local takes precedence)
ENV_FILE=""
if [ -f ".env.local" ]; then
    ENV_FILE=".env.local"
elif [ -f ".env" ]; then
    ENV_FILE=".env"
fi

if [ -n "$ENV_FILE" ]; then
    set -a
    # shellcheck disable=SC1090
    . "$ENV_FILE"
    set +a
fi

if ! python3 -c "import can" >/dev/null 2>&1; then
    echo "[fatal] Missing dependency: python-can"
    echo "        Install with: python3 -m pip install python-can"
    exit 1
fi

PIDS=()
SCRIPTS=("Cancom.py" "api.py")
LOGS=("cancom.log" "api.log")

start_service() {
    local idx="$1"
    local script="${SCRIPTS[$idx]}"
    local log_file="${LOGS[$idx]}"

    python3 "$script" >> "logs/$log_file" 2>&1 &
    PIDS[$idx]="$!"
    echo "[info] started $script (pid=${PIDS[$idx]})"
}

cleanup() {
    for pid in "${PIDS[@]:-}"; do
        if kill -0 "$pid" >/dev/null 2>&1; then
            kill "$pid" >/dev/null 2>&1 || true
        fi
    done
}

trap cleanup INT TERM

mkdir -p logs

for i in "${!SCRIPTS[@]}"; do
    start_service "$i"
done

# Keep stack alive: restart any child that exits unexpectedly.
while true; do
    sleep 2
    for i in "${!PIDS[@]}"; do
        pid="${PIDS[$i]}"
        if ! kill -0 "$pid" >/dev/null 2>&1; then
            echo "[warn] ${SCRIPTS[$i]} exited; restarting..."
            start_service "$i"
        fi
    done
done
