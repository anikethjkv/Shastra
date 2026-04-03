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

cleanup() {
    for pid in "${PIDS[@]:-}"; do
        if kill -0 "$pid" >/dev/null 2>&1; then
            kill "$pid" >/dev/null 2>&1 || true
        fi
    done
}

trap cleanup INT TERM

python3 Cancom.py &
PIDS+=("$!")

python3 SensorReader.py &
PIDS+=("$!")

python3 api.py &
PIDS+=("$!")

# Exit (and let systemd restart) if any child exits unexpectedly.
wait -n "${PIDS[@]}"
status=$?
echo "[fatal] A dashboard service exited unexpectedly (status=$status)."
cleanup
wait || true
exit "$status"
