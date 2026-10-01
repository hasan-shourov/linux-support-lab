#!/usr/bin/env bash
# Scenario 08: stop only the workers the lab started.
set -euo pipefail

SCENARIO_ID="08-high-cpu"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common.sh"

PID_FILE="${LAB_STATE_DIR}/workers.pid"

begin_fix "$SCENARIO_ID" 0

info "Stopping the recorded workers"
kill_recorded_pids "$PID_FILE" "timeout 1800 yes"
if ! dry_run; then
    sleep 1
fi

no_workers_left() { ! pgrep -f "timeout 1800 yes" >/dev/null 2>&1; }

check "No lab CPU workers are running" no_workers_left

finish_fix "$SCENARIO_ID"
