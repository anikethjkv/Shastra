#!/bin/bash
set -euo pipefail

DASHBOARD_URL="${DASHBOARD_URL:-http://127.0.0.1:8080}"
WORKDIR="$(cd "$(dirname "$0")/.." && pwd)"

start_backend_if_missing() {
    local script="$1"
    local log_file="$2"

    if ! pgrep -f "python3 $script" >/dev/null 2>&1; then
        nohup python3 "$WORKDIR/$script" >> "$WORKDIR/logs/$log_file" 2>&1 &
        sleep 0.2
    fi
}

mkdir -p "$WORKDIR/logs"

# Ensure all three backend services are running before kiosk opens.
start_backend_if_missing "Cancom.py" "cancom.log"
start_backend_if_missing "api.py" "api.log"

# Give API some time to come up after boot.
sleep 8

# Wait until dashboard is reachable.
for _ in $(seq 1 60); do
    if curl -fsS "$DASHBOARD_URL" >/dev/null 2>&1; then
        break
    fi
    sleep 1
done

BROWSER_CMD=""
if command -v chromium-browser >/dev/null 2>&1; then
    BROWSER_CMD="chromium-browser"
elif command -v chromium >/dev/null 2>&1; then
    BROWSER_CMD="chromium"
else
    echo "[fatal] Chromium not found (expected chromium-browser or chromium)."
    exit 1
fi

exec "$BROWSER_CMD" \
    --kiosk \
    --app="$DASHBOARD_URL" \
    --incognito \
    --noerrdialogs \
    --disable-infobars \
    --check-for-update-interval=31536000 \
    --simulate-outdated-no-au='Tue, 31 Dec 2099 23:59:59 GMT' \
    --overscroll-history-navigation=0 \
    --disable-pinch \
    "$DASHBOARD_URL"
