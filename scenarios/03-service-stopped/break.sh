#!/usr/bin/env bash
# Scenario 03: stop the nginx web server.
set -euo pipefail

SCENARIO_ID="03-service-stopped"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common.sh"

begin_break "$SCENARIO_ID" 1 "This stops the nginx web server, so the website goes offline."
need_cmd nginx systemctl curl

if [ -z "$(note_get nginx_was_active)" ]; then
    note_set nginx_was_active "$(systemctl is-active nginx 2>/dev/null || true)"
fi

set_active "$SCENARIO_ID"
arm_failure_notice

run systemctl stop nginx

if ! dry_run; then
    if curl -s -o /dev/null --max-time 3 http://localhost; then
        error "The site still answers, so the break did not work."
        exit 1
    fi
    ok "nginx is stopped and the site no longer answers"
fi

finish_break "The website should be down now."
if ! dry_run; then
    print_ticket "Our company website is down! Visitors see an error page and nobody changed anything on our side. This is urgent, we are losing orders."
fi
