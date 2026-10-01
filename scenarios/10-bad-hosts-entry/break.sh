#!/usr/bin/env bash
# Scenario 10: add a wrong line for example.com to /etc/hosts.
set -euo pipefail

SCENARIO_ID="10-bad-hosts-entry"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common.sh"

HOSTS="/etc/hosts"
MARKER="# troubleshooting-lab"
BAD_LINE="203.0.113.10 example.com ${MARKER}" # 203.0.113.0/24 is reserved for documentation

begin_break "$SCENARIO_ID" 0 "This adds a wrong address for example.com to ${HOSTS}."

backup_file "$HOSTS"

set_active "$SCENARIO_ID"
arm_failure_notice

if ! dry_run && grep -qF -- "$MARKER" "$HOSTS"; then
    info "The lab entry is already in ${HOSTS}, so nothing more is needed."
else
    info "Adding: ${BAD_LINE}"
    append_line "$HOSTS" "$BAD_LINE"
fi

if ! dry_run; then
    resolved="$(getent ahostsv4 example.com || true)"
    if grep -q '203.0.113.10' <<< "$resolved"; then
        ok "The system (getaddrinfo, like curl and ping) now resolves example.com to 203.0.113.10"
    else
        error "example.com does not resolve to the lab address. Is /etc/nsswitch.conf using the hosts file?"
        exit 1
    fi
fi

finish_break "curl and ping should now go to the wrong address."
if ! dry_run; then
    print_ticket "Hello, one website (example.com) will not open from our server. Other websites work fine. A colleague says it opens from his laptop. Can you take a look? It is not blocking us, but it is annoying."
fi
