#!/usr/bin/env bash
# Scenario 01: put /etc/resolv.conf back exactly as it was.
set -euo pipefail

SCENARIO_ID="01-dns-failure"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common.sh"

RESOLV="/etc/resolv.conf"
BAD_NS="192.0.2.53"

begin_fix "$SCENARIO_ID" 0

kind="$(note_get resolv_kind)"
target="$(note_get resolv_target)"
method="$(note_get resolv_method)"

if [ "$kind" = "symlink" ] && [ "$method" = "replace" ]; then
    info "Restoring the symlink ${RESOLV} -> ${target}"
    run rm -f -- "$RESOLV"
    run ln -s -- "$target" "$RESOLV"
else
    info "Restoring the original content of ${RESOLV}"
    restore_file "$RESOLV"
fi

if command -v resolvectl >/dev/null 2>&1; then
    run resolvectl flush-caches || true
fi

symlink_restored() { [ "$(readlink "$RESOLV" 2>/dev/null)" = "$target" ]; }
bad_nameserver_gone() { ! grep -q "$BAD_NS" "$RESOLV"; }

check_lookup() {
    if dry_run; then
        dry "verify: example.com resolves again"
        return 0
    fi
    if timeout 15 getent hosts example.com >/dev/null 2>&1; then
        ok "Name lookup works again"
    elif have_internet; then
        error "The internet works by IP address but names still do not resolve"
        FIX_FAILURES=$((FIX_FAILURES + 1))
    else
        warn "This machine has no internet access, so the name lookup test was skipped."
    fi
}

if [ "$kind" = "symlink" ] && [ "$method" = "replace" ]; then
    check "${RESOLV} is a symlink to ${target} again" symlink_restored
fi
check "${RESOLV} no longer lists ${BAD_NS}" bad_nameserver_gone
check_lookup

finish_fix "$SCENARIO_ID"
