#!/usr/bin/env bash
# Scenario 10: remove only the lines that carry the lab marker from /etc/hosts.
set -euo pipefail

SCENARIO_ID="10-bad-hosts-entry"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common.sh"

HOSTS="/etc/hosts"
MARKER="# troubleshooting-lab"

begin_fix "$SCENARIO_ID" 0

info "Removing the lines marked '${MARKER}' from ${HOSTS}"
if dry_run; then
    dry "remove every line containing '${MARKER}' from ${HOSTS}"
else
    tmp="$(mktemp)"
    # grep exits with 1 when it prints nothing, which is fine here.
    grep -vF -- "$MARKER" "$HOSTS" > "$tmp" || true
    # Write in place (not mv) because /etc/hosts is a bind mount in many containers.
    cat -- "$tmp" > "$HOSTS"
    rm -f -- "$tmp"
fi

marker_gone() { ! grep -qF -- "$MARKER" "$HOSTS"; }
not_resolved_to_bad_ip() {
    local resolved
    resolved="$(getent ahostsv4 example.com || true)"
    ! grep -q '203.0.113.10' <<< "$resolved"
}

check "No lab lines are left in ${HOSTS}" marker_gone
check "example.com no longer resolves to 203.0.113.10" not_resolved_to_bad_ip

finish_fix "$SCENARIO_ID"
