#!/usr/bin/env bash
# lab.sh - command line tool for the Linux Troubleshooting Lab.
# Run ./lab.sh --help for usage.
set -euo pipefail

LAB_VERSION="1.0.0"
LAB_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCENARIOS_DIR="${LAB_ROOT}/scenarios"

# shellcheck source-path=SCRIPTDIR
# shellcheck source=lib/common.sh
source "${LAB_ROOT}/lib/common.sh"

usage() {
    cat <<EOF
Linux Troubleshooting Lab ${LAB_VERSION}

Break an Ubuntu server on purpose, diagnose it, fix it and write it up like a ticket.

Usage:
  ./lab.sh list              Show the 10 scenarios and whether one is BROKEN
  ./lab.sh break <N>         Start scenario N (3 or 03 both work)
  ./lab.sh fix <N>           Fix scenario N and check that it worked (PASS or FAIL)
  ./lab.sh status            Show the active scenario, if any
  ./lab.sh hint <N>          Show the first command to try
  ./lab.sh solution <N>      Show the full write-up (this is a spoiler)
  ./lab.sh reset             Fix the active scenario and remove all lab state
  ./lab.sh --help | -h       Show this help
  ./lab.sh --version         Show the version

Flags:
  --yes                      Skip the confirmation question
  --dry-run                  Print every action without running it (no root needed)
  --with-password-disable    Scenario 7 only: also turn off SSH password login

Only one scenario can be active at a time. Run the lab only in a disposable VM or
container. break, fix and reset need root (use sudo). All other commands do not.
EOF
}

COMMAND=""
ARG=""
EXTRA_ARGS=()
LAB_YES="${LAB_YES:-0}"
LAB_DRY_RUN="${LAB_DRY_RUN:-0}"

while [ "$#" -gt 0 ]; do
    case "$1" in
        -h | --help)
            usage
            exit 0
            ;;
        --version)
            echo "linux-troubleshooting-lab ${LAB_VERSION}"
            exit 0
            ;;
        --yes) LAB_YES=1 ;;
        --dry-run) LAB_DRY_RUN=1 ;;
        --with-password-disable) EXTRA_ARGS+=("$1") ;;
        -*)
            error "Unknown option: $1"
            usage >&2
            exit 1
            ;;
        *)
            if [ -z "$COMMAND" ]; then
                COMMAND="$1"
            elif [ -z "$ARG" ]; then
                ARG="$1"
            else
                error "Too many arguments: $1"
                exit 1
            fi
            ;;
    esac
    shift
done
export LAB_YES LAB_DRY_RUN

scenario_ids() {
    local dir
    for dir in "${SCENARIOS_DIR}"/*/; do
        if [ -d "$dir" ]; then
            basename "$dir"
        fi
    done
}

# resolve_scenario <number>: print the folder name, for example 03-service-stopped.
resolve_scenario() {
    local raw="${1:-}" n dir
    case "$raw" in
        '' | *[!0-9]*)
            error "Please give a scenario number from 1 to 10 (got '${raw}')."
            exit 1
            ;;
    esac
    if [ "${#raw}" -gt 3 ]; then
        error "Scenario numbers go from 1 to 10 (got '${raw}')."
        exit 1
    fi
    printf -v n '%02d' "$((10#$raw))"
    for dir in "${SCENARIOS_DIR}/${n}-"*/; do
        if [ -d "$dir" ]; then
            basename "$dir"
            return 0
        fi
    done
    error "There is no scenario number ${raw}. Run ./lab.sh list to see all of them."
    exit 1
}

readme_field() {
    sed -n "s/^\*\*${2}:\*\* *//p" "${SCENARIOS_DIR}/${1}/README.md" 2>/dev/null | head -n1 || true
}

cmd_list() {
    local id name difficulty active state
    active="$(get_active)"
    printf '\n%-4s %-22s %-13s %s\n' "No." "Scenario" "Difficulty" "Status"
    printf '%-4s %-22s %-13s %s\n' "---" "----------------------" "-------------" "------"
    while IFS= read -r id; do
        name="${id#*-}"
        difficulty="$(readme_field "$id" Difficulty)"
        if [ "$id" = "$active" ]; then
            state="${C_RED}BROKEN${C_RESET}"
        else
            state="${C_GREEN}OK${C_RESET}"
        fi
        printf '%-4s %-22s %-13s %s\n' "${id%%-*}" "$name" "${difficulty:--}" "$state"
    done < <(scenario_ids)
    printf '\n'
    if [ -n "$active" ]; then
        warn "Scenario ${active} is active. Fix it with: ./lab.sh fix $(scenario_number "$active")"
    else
        info "No scenario is active. Start one with: ./lab.sh break 3"
    fi
}

cmd_status() {
    local active started
    active="$(get_active)"
    if [ -z "$active" ]; then
        info "No scenario is active. The system is in its normal state."
        return 0
    fi
    started="$(get_active_started)"
    warn "Active scenario: ${active} (started ${started:-unknown time})"
    info "Need a nudge? ./lab.sh hint $(scenario_number "$active")"
    info "Finished? ./lab.sh fix $(scenario_number "$active")"
}

cmd_hint() {
    local id
    id="$(resolve_scenario "$ARG")"
    cat "${SCENARIOS_DIR}/${id}/hint.txt"
}

cmd_solution() {
    local id
    id="$(resolve_scenario "$ARG")"
    cat "${SCENARIOS_DIR}/${id}/README.md"
}

cmd_scenario_script() {
    local action="$1" id
    id="$(resolve_scenario "$ARG")"
    if [ "$action" = "break" ]; then
        bash "${SCENARIOS_DIR}/${id}/break.sh" ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
    else
        bash "${SCENARIOS_DIR}/${id}/fix.sh"
    fi
}

cmd_reset() {
    local active
    require_root
    if ! confirm "Reset the lab? This fixes the active scenario and deletes all lab state and backups."; then
        info "Cancelled. Nothing was changed."
        exit 1
    fi
    active="$(get_active)"
    if [ -n "$active" ]; then
        info "Fixing the active scenario (${active}) first."
        if ! LAB_YES=1 bash "${SCENARIOS_DIR}/${active}/fix.sh"; then
            error "The automatic fix did not finish. Your backups were kept in ${LAB_BACKUP_DIR}."
            error "Follow the manual fix in scenarios/${active}/README.md, then run reset again."
            exit 1
        fi
    fi
    cancel_all_reverts
    kill_recorded_pids "${LAB_STATE_DIR}/workers.pid" "timeout 1800 yes"
    kill_recorded_pids "${LAB_STATE_DIR}/listener.pid" "http.server 80"
    wipe_lab_state
    if dry_run; then
        info "Dry run finished. Nothing was changed."
    else
        ok "Lab state cleaned up. The system is back to normal."
    fi
}

case "$COMMAND" in
    list) cmd_list ;;
    status) cmd_status ;;
    hint) cmd_hint ;;
    solution) cmd_solution ;;
    break) cmd_scenario_script break ;;
    fix) cmd_scenario_script fix ;;
    reset) cmd_reset ;;
    '')
        usage >&2
        exit 1
        ;;
    *)
        error "Unknown command: ${COMMAND}"
        usage >&2
        exit 1
        ;;
esac
