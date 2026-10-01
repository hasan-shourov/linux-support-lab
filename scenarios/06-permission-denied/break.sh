#!/usr/bin/env bash
# Scenario 06: make the web root unreadable for nginx so it answers 403.
set -euo pipefail

SCENARIO_ID="06-permission-denied"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common.sh"

WEBROOT="/var/www/html"

begin_break "$SCENARIO_ID" 0 "This changes the owner and permissions of ${WEBROOT} so nginx cannot read it."
need_cmd nginx curl stat

# Record the original owner, group and mode once. A second run keeps the first record.
if [ -z "$(note_get webroot_owner)" ]; then
    if [ -d "$WEBROOT" ]; then
        note_set webroot_owner "$(stat -c '%U' "$WEBROOT")"
        note_set webroot_group "$(stat -c '%G' "$WEBROOT")"
        note_set webroot_mode "$(stat -c '%a' "$WEBROOT")"
        info "Original: owner $(stat -c '%U:%G' "$WEBROOT"), mode $(stat -c '%a' "$WEBROOT")"
    elif dry_run; then
        warn "${WEBROOT} does not exist here. Run ./setup.sh first. Continuing the dry run."
    else
        error "${WEBROOT} does not exist. Run ./setup.sh first."
        exit 1
    fi
fi

set_active "$SCENARIO_ID"
arm_failure_notice

run chown root:root "$WEBROOT"
run chmod 700 "$WEBROOT"

if ! dry_run; then
    code="$(curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost || true)"
    if [ "$code" = "403" ]; then
        ok "nginx now answers HTTP 403 Forbidden"
    else
        warn "Expected HTTP 403 but got ${code}. Is nginx running? (try: ./setup.sh)"
    fi
fi

finish_break "The site should return 403 Forbidden."
if ! dry_run; then
    print_ticket "Good morning, our website now shows '403 Forbidden' instead of the home page. Yesterday a colleague was tidying up the server files. It worked fine before that. Please help soon."
fi
