#!/usr/bin/env bash
# Scenario 01: point /etc/resolv.conf at a nameserver that does not answer.
set -euo pipefail

SCENARIO_ID="01-dns-failure"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common.sh"

RESOLV="/etc/resolv.conf"
BAD_NS="192.0.2.53" # 192.0.2.0/24 is reserved for documentation, so nobody answers there

begin_break "$SCENARIO_ID" 0 "This changes the DNS server in ${RESOLV} to ${BAD_NS}, which does not answer."

# Remember what the file looked like before. A second run keeps the first record.
kind="$(note_get resolv_kind)"
target="$(note_get resolv_target)"
if [ -z "$kind" ]; then
    if [ -L "$RESOLV" ]; then
        kind="symlink"
        target="$(readlink "$RESOLV")"
        info "${RESOLV} is a symlink to ${target}"
    else
        kind="file"
        target=""
        info "${RESOLV} is a regular file"
    fi
    note_set resolv_kind "$kind"
    note_set resolv_target "$target"
    if [ -e "$RESOLV" ]; then
        backup_file "$RESOLV"
    fi
fi

set_active "$SCENARIO_ID"
arm_failure_notice

printf -v content '# Written by troubleshooting-lab (scenario 01). Undo with: ./lab.sh fix 1\nnameserver %s' "$BAD_NS"

# A symlink is replaced by a regular file. If that is not possible (for example a
# bind mount in a container), the file is edited in place and its content is restored later.
method="inplace"
if [ "$kind" = "symlink" ]; then
    if dry_run; then
        dry "rm -f -- ${RESOLV}   (replace the symlink with a regular file)"
        method="replace"
    elif rm -f -- "$RESOLV" 2>/dev/null; then
        method="replace"
    else
        warn "Could not replace the symlink. Editing the file in place instead."
    fi
fi
note_set resolv_method "$method"
write_file "$RESOLV" "$content"

if command -v resolvectl >/dev/null 2>&1; then
    run resolvectl flush-caches || true
fi

if ! dry_run; then
    if grep -q "$BAD_NS" "$RESOLV"; then
        ok "${RESOLV} now points to ${BAD_NS}"
    else
        error "${RESOLV} was not changed as expected."
        exit 1
    fi
fi

finish_break "Name lookups should fail now."
if ! dry_run; then
    print_ticket "Hi support, our server can reach the internet by IP address but nothing can be opened by name. Package updates fail too and we have a customer demo this afternoon."
fi
