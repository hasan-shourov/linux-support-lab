#!/usr/bin/env bash
# Scenario 09: stop the rogue listener and start nginx again.
set -euo pipefail

SCENARIO_ID="09-port-conflict"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common.sh"

PID_FILE="${LAB_STATE_DIR}/listener.pid"
LOG_FILE="${LAB_STATE_DIR}/listener.log"
WEB_DIR="${LAB_STATE_DIR}/empty-web"

begin_fix "$SCENARIO_ID" 1
need_cmd nginx systemctl curl ss

info "Stopping the program that is using port 80"
kill_recorded_pids "$PID_FILE" "http.server 80"

if ! dry_run; then
    for _ in 1 2 3 4 5 6 7 8 9 10; do
        if [ -z "$(ss -ltnH 'sport = :80' 2>/dev/null || true)" ]; then
            break
        fi
        sleep 0.5
    done
fi
run rm -rf -- "$WEB_DIR" "$LOG_FILE"

info "Starting nginx"
run systemctl reset-failed nginx
run systemctl start nginx

nginx_running() { systemctl is-active --quiet nginx; }
site_answers() { curl -fsS -o /dev/null --max-time 5 http://localhost; }
nginx_owns_port() {
    local listeners
    listeners="$(ss -ltnpH 'sport = :80' 2>/dev/null || true)"
    grep -q 'nginx' <<< "$listeners"
}

check "nginx is running" nginx_running
check "nginx is the program listening on port 80" nginx_owns_port
check "The site answers on http://localhost" site_answers

finish_fix "$SCENARIO_ID"
