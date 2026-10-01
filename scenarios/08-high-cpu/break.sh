#!/usr/bin/env bash
# Scenario 08: start one CPU-hungry background worker per core (they stop after 30 minutes).
set -euo pipefail

SCENARIO_ID="08-high-cpu"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common.sh"

PID_FILE="${LAB_STATE_DIR}/workers.pid"
WORKER_SECONDS=1800

workers="$(nproc)"

begin_break "$SCENARIO_ID" 0 "This starts ${workers} low-priority CPU workers. They stop by themselves after 30 minutes."

set_active "$SCENARIO_ID"
arm_failure_notice

if [ -s "$PID_FILE" ] && ! dry_run; then
    info "Workers are already recorded in ${PID_FILE}, so no new ones are started."
else
    info "Starting ${workers} worker(s): nice -n 10 timeout ${WORKER_SECONDS} yes > /dev/null"
    if dry_run; then
        dry "start ${workers} background worker(s) and record their PIDs in ${PID_FILE}"
    else
        mkdir -p "$LAB_STATE_DIR"
        : > "$PID_FILE"
        for ((n = 1; n <= workers; n++)); do
            nice -n 10 timeout "$WORKER_SECONDS" yes > /dev/null 2>&1 < /dev/null &
            printf '%s\n' "$!" >> "$PID_FILE"
        done
        ok "Started ${workers} worker(s). PIDs are saved in ${PID_FILE}"
    fi
fi

finish_break "CPU usage should climb to 100 percent within a few seconds."
if ! dry_run; then
    print_ticket "The server has become very slow. SSH takes forever to respond and the website is sluggish. Nothing was deployed today. Our customers are starting to complain."
fi
