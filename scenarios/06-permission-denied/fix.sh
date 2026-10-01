#!/usr/bin/env bash
# Scenario 06: restore the original owner, group and mode of the web root.
set -euo pipefail

SCENARIO_ID="06-permission-denied"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common.sh"

WEBROOT="/var/www/html"

begin_fix "$SCENARIO_ID" 0
need_cmd curl stat

owner="$(note_get webroot_owner)"
group="$(note_get webroot_group)"
mode="$(note_get webroot_mode)"
if [ -z "$owner" ]; then
    if dry_run; then
        owner="<original-owner>" group="<original-group>" mode="<original-mode>"
    else
        error "No saved owner and mode were found, so they cannot be restored automatically."
        exit 1
    fi
fi

info "Restoring ${WEBROOT}: owner ${owner}:${group}, mode ${mode}"
run chown "${owner}:${group}" "$WEBROOT"
run chmod "$mode" "$WEBROOT"

permissions_restored() {
    [ "$(stat -c '%U:%G %a' "$WEBROOT")" = "${owner}:${group} ${mode}" ]
}
site_answers() { curl -fsS -o /dev/null --max-time 5 http://localhost; }

check "${WEBROOT} has owner ${owner}:${group} and mode ${mode} again" permissions_restored
if ! dry_run; then
    if pgrep -x nginx >/dev/null 2>&1; then
        check "The site answers HTTP 200 again" site_answers
    else
        warn "nginx is not running, so the HTTP test was skipped."
    fi
fi

finish_fix "$SCENARIO_ID"
