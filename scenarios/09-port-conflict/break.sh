#!/usr/bin/env bash
# Scenario 09: let another program take port 80 so nginx cannot start.
set -euo pipefail

SCENARIO_ID="09-port-conflict"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common.sh"

PID_FILE="${LAB_STATE_DIR}/listener.pid"
LOG_FILE="${LAB_STATE_DIR}/listener.log"
WEB_DIR="${LAB_STATE_DIR}/empty-web" # an empty folder, so the rogue server never exposes real files

begin_break "$SCENARIO_ID" 1 "This stops nginx and starts another program on port 80, so nginx cannot start."
need_cmd nginx python3 systemctl ss

if [ -z "$(note_get nginx_was_active)" ]; then
    note_set nginx_was_active "$(systemctl is-active nginx 2>/dev/null || true)"
fi

set_active "$SCENARIO_ID"
arm_failure_notice

run systemctl stop nginx

if dry_run; then
    dry "python3 -m http.server 80 --bind 0.0.0.0 --directory ${WEB_DIR}   (background, PID saved in ${PID_FILE})"
else
    mkdir -p "$WEB_DIR"
    if [ -s "$PID_FILE" ] && kill -0 "$(head -n1 "$PID_FILE")" 2>/dev/null; then
        info "The rogue listener is already running (PID $(head -n1 "$PID_FILE"))."
    else
        nohup python3 -m http.server 80 --bind 0.0.0.0 --directory "$WEB_DIR" \
            > "$LOG_FILE" 2>&1 < /dev/null &
        printf '%s\n' "$!" > "$PID_FILE"
        sleep 1
    fi
    if [ -z "$(ss -ltnH 'sport = :80' 2>/dev/null || true)" ]; then
        error "The rogue listener did not start. See ${LOG_FILE}"
        exit 1
    fi
    ok "Another program (python3, PID $(head -n1 "$PID_FILE")) is now listening on port 80"
fi

info "Starting nginx. It should fail now because port 80 is taken."
if run systemctl start nginx; then
    warn "nginx started anyway. Something else is going on, check the port with: ss -tulpn | grep :80"
else
    info "nginx failed to start, as intended."
fi

finish_break "nginx should be down and port 80 should be in use."
if ! dry_run; then
    print_ticket "We restarted the web server after an update and now it will not come back. The site is down. The restart command just says it failed. This is urgent."
fi
