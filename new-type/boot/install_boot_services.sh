#!/bin/bash
set -euo pipefail

if [ "${EUID}" -ne 0 ]; then
    echo "Run as root: sudo bash ./boot/install_boot_services.sh"
    exit 1
fi

WORKDIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE_DIR="$WORKDIR/boot/systemd"
OUT_DIR="/etc/systemd/system"
RUN_USER="${SUDO_USER:-$USER}"
DASHBOARD_URL="${DASHBOARD_URL:-http://127.0.0.1:8080}"

DASHBOARD_TEMPLATE="$TEMPLATE_DIR/shastra-dashboard.service.template"
KIOSK_TEMPLATE="$TEMPLATE_DIR/shastra-kiosk.service.template"

if [ ! -f "$DASHBOARD_TEMPLATE" ] || [ ! -f "$KIOSK_TEMPLATE" ]; then
    echo "[fatal] Missing service template(s) in $TEMPLATE_DIR"
    exit 1
fi

mkdir -p "$WORKDIR/logs"
chown -R "$RUN_USER:$RUN_USER" "$WORKDIR/logs"
chmod 755 "$WORKDIR/logs"
chmod +x "$WORKDIR/boot/launch_stack.sh" "$WORKDIR/boot/open_kiosk.sh"

render_service() {
    local in_file="$1"
    local out_file="$2"
    sed \
        -e "s|__RUN_USER__|$RUN_USER|g" \
        -e "s|__WORKDIR__|$WORKDIR|g" \
        -e "s|__DASHBOARD_URL__|$DASHBOARD_URL|g" \
        "$in_file" > "$out_file"
}

render_service "$DASHBOARD_TEMPLATE" "$OUT_DIR/shastra-dashboard.service"
render_service "$KIOSK_TEMPLATE" "$OUT_DIR/shastra-kiosk.service"

systemctl daemon-reload
systemctl enable --now shastra-dashboard.service
systemctl enable --now shastra-kiosk.service

echo "[ok] Installed and started services:"
echo "     - shastra-dashboard.service"
echo "     - shastra-kiosk.service"
echo "[hint] Logs: $WORKDIR/logs/shastra-dashboard.log"
