# Shastra `new-type`

## Boot services (systemd)

- Install and start on boot:
  - `cd /path/to/Shastra/new-type && sudo bash ./boot/install_boot_services.sh`
- Uninstall and remove services:
  - `cd /path/to/Shastra/new-type && sudo bash ./boot/uninstall_boot_services.sh`

Optional dashboard URL override during install:
- `cd /path/to/Shastra/new-type && sudo DASHBOARD_URL=http://127.0.0.1:8080 bash ./boot/install_boot_services.sh`
