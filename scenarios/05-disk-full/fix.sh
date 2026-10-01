#!/usr/bin/env bash
# Scenario 05: delete the big file.
set -euo pipefail

SCENARIO_ID="05-disk-full"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common.sh"

BIGFILE="/var/tmp/.lab-bigfile"

begin_fix "$SCENARIO_ID" 0

info "Removing ${BIGFILE}"
run rm -f -- "$BIGFILE"

file_gone() { [ ! -e "$BIGFILE" ]; }

check "${BIGFILE} is gone" file_gone
if ! dry_run; then
    free_mb="$(df -Pm /var/tmp | awk 'NR==2 {print $4}')"
    before="$(note_get free_mb_before)"
    info "Free space on /var/tmp is now ${free_mb} MB (before the lab: ${before:-unknown} MB)"
fi

finish_fix "$SCENARIO_ID"
