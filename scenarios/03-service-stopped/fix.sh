#!/usr/bin/env bash
# Scenario 03: start nginx again.
set -euo pipefail

SCENARIO_ID="03-service-stopped"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common.sh"

begin_fix "$SCENARIO_ID" 1
need_cmd nginx systemctl curl

info "Starting nginx"
run systemctl start nginx

nginx_running() { systemctl is-active --quiet nginx; }
site_answers() { curl -fsS -o /dev/null --max-time 5 http://localhost; }

check "nginx is running" nginx_running
check "The site answers on http://localhost" site_answers

finish_fix "$SCENARIO_ID"
