#!/bin/bash
set -euo pipefail

OUT_DIR="/etc/systemd/system"

if [ "${EUID}" -ne 0 ]; then
    echo "Run as root: sudo bash ./boot/uninstall_boot_services.sh"
    exit 1
fi

for svc in shastra-kiosk.service shastra-dashboard.service; do
    if systemctl list-unit-files | grep -q "^${svc}"; then
        systemctl disable --now "$svc" || true
    else
        systemctl stop "$svc" >/dev/null 2>&1 || true
    fi

    rm -f "$OUT_DIR/$svc"
done

systemctl daemon-reload
systemctl reset-failed

echo "[ok] Removed services:"
echo "     - shastra-dashboard.service"
echo "     - shastra-kiosk.service"
