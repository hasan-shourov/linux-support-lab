#!/usr/bin/env bash
# setup.sh - install the tools the lab needs and prepare the demo web page.
# Run it once on a fresh Ubuntu or Debian machine: sudo ./setup.sh
set -euo pipefail

LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib/common.sh
source "${LAB_ROOT}/lib/common.sh"

# The nine tools from the project brief, plus iproute2 (ip, ss), traceroute, python3
# and openssh-server, which scenarios 02, 07 and 09 use.
PACKAGES=(
    nginx ufw curl dnsutils net-tools lsof htop sysstat shellcheck
    iproute2 traceroute python3 openssh-server
)
INDEX_FILE="/var/www/html/index.html"
INDEX_MARKER="troubleshooting-lab demo page"

case "${1:-}" in
    -h | --help)
        cat <<EOF
Usage: sudo ./setup.sh

Installs: ${PACKAGES[*]}
Writes a demo page to ${INDEX_FILE} and starts nginx.
EOF
        exit 0
        ;;
    '') ;;
    *)
        error "Unknown option: $1"
        exit 1
        ;;
esac

check_os
require_root

info "Installing packages. This can take a few minutes."
export DEBIAN_FRONTEND=noninteractive
apt-get update -qq
apt-get install -y -qq "${PACKAGES[@]}"
ok "Packages installed"

mkdir -p /var/www/html
if [ ! -e "$INDEX_FILE" ] || grep -q "$INDEX_MARKER" "$INDEX_FILE"; then
    cat > "$INDEX_FILE" <<EOF
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <title>Troubleshooting Lab</title>
</head>
<body>
  <!-- ${INDEX_MARKER} -->
  <h1>Troubleshooting Lab</h1>
  <p>nginx is working.</p>
</body>
</html>
EOF
    ok "Wrote the demo page ${INDEX_FILE}"
else
    warn "${INDEX_FILE} already exists and was not created by the lab. Leaving it alone."
fi

if have_systemd; then
    systemctl enable --now nginx
    ok "nginx is enabled and running"
else
    warn "systemd is not running (normal in a container). Starting nginx directly."
    if ! pgrep -x nginx >/dev/null 2>&1 && ! nginx; then
        error "nginx could not start."
        error "If the message above mentions [::]:80, IPv6 is disabled on this machine."
        error "Remove the 'listen [::]:80' line from /etc/nginx/sites-enabled/default, then run ./setup.sh again."
        exit 1
    fi
    ok "nginx is running"
fi

ok "Setup finished. Next: ./lab.sh list"
