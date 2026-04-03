#!/bin/bash
set -euo pipefail

WORKDIR="$(cd "$(dirname "$0")/.." && pwd)"
TEMPLATE_DIR="$WORKDIR/boot/systemd"
OUT_DIR="/etc/systemd/system"
LOG_DIR="$WORKDIR/logs"

RUN_USER="${SUDO_USER:-${USER}}"
DASHBOARD_URL="${DASHBOARD_URL:-http://127.0.0.1:8080}"

if [ "${EUID}" -ne 0 ]; then
    echo "Run as root: sudo bash $WORKDIR/boot/install_boot_services.sh"
    exit 1
fi

mkdir -p "$LOG_DIR"
chmod 755 "$WORKDIR/boot/launch_stack.sh" "$WORKDIR/boot/open_kiosk.sh"

render_template() {
    local in_file="$1"
    local out_file="$2"

    sed \
        -e "s|__RUN_USER__|$RUN_USER|g" \
        -e "s|__WORKDIR__|$WORKDIR|g" \
        -e "s|__DASHBOARD_URL__|$DASHBOARD_URL|g" \
        "$in_file" > "$out_file"
}

render_template \
    "$TEMPLATE_DIR/shastra-dashboard.service.template" \
    "$OUT_DIR/shastra-dashboard.service"

render_template \
    "$TEMPLATE_DIR/shastra-kiosk.service.template" \
    "$OUT_DIR/shastra-kiosk.service"

systemctl daemon-reload
systemctl enable shastra-dashboard.service
systemctl enable shastra-kiosk.service

systemctl restart shastra-dashboard.service
systemctl restart shastra-kiosk.service

echo "[ok] Installed and enabled boot services:"
echo "     - shastra-dashboard.service"
echo "     - shastra-kiosk.service"
echo
echo "Check status with:"
echo "  systemctl status shastra-dashboard.service"
echo "  systemctl status shastra-kiosk.service"
