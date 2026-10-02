#!/usr/bin/env bash
# lib/common.sh - shared helpers for the Linux Troubleshooting Lab.
# This file is sourced by lab.sh and by every scenario script. Do not run it directly.

LAB_STATE_DIR="${LAB_STATE_DIR:-/var/lib/troubleshooting-lab}"
LAB_BACKUP_DIR="${LAB_BACKUP_DIR:-/var/backups/troubleshooting-lab}"
LAB_STATE_FILE="${LAB_STATE_DIR}/active.state"

# Number of failed checks in the current fix run (see check and finish_fix).
FIX_FAILURES=0
LAB_FIXING=""
LAB_ARMED=0

# ---------------------------------------------------------------------------
# Output and colors (colors are off when stdout is not a terminal)
# ---------------------------------------------------------------------------

_init_colors() {
    C_RESET='' C_BOLD='' C_RED='' C_GREEN='' C_BLUE=''
    E_RESET='' E_RED='' E_YELLOW=''
    if [ -z "${NO_COLOR:-}" ]; then
        if [ -t 1 ]; then
            C_RESET=$'\033[0m' C_BOLD=$'\033[1m' C_RED=$'\033[31m'
            C_GREEN=$'\033[32m' C_BLUE=$'\033[34m'
        fi
        if [ -t 1 ] && [ -t 2 ]; then
            E_RESET=$'\033[0m' E_RED=$'\033[31m' E_YELLOW=$'\033[33m'
        fi
    fi
}
_init_colors

dry_run() { [ "${LAB_DRY_RUN:-0}" = "1" ]; }

dry() { printf '[DRY-RUN] %s\n' "$*"; }
info() { printf '%s[INFO]%s %s\n' "$C_BLUE" "$C_RESET" "$*"; }
ok() { printf '%s[ OK ]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
warn() { printf '%s[WARN]%s %s\n' "$E_YELLOW" "$E_RESET" "$*" >&2; }
error() { printf '%s[ERROR]%s %s\n' "$E_RED" "$E_RESET" "$*" >&2; }
pass() { printf '%s[PASS]%s %s\n' "$C_GREEN" "$C_RESET" "$*"; }
fail() { printf '%s[FAIL]%s %s\n' "$C_RED" "$C_RESET" "$*"; }
bold() { printf '%s%s%s\n' "$C_BOLD" "$*" "$C_RESET"; }

# run <command...>: run a command, or only print it when --dry-run is active.
run() {
    if dry_run; then
        dry "$*"
        return 0
    fi
    "$@"
}

# write_file <path> <text>: replace the content of a file in place (keeps the inode,
# which matters for bind-mounted files in containers).
write_file() {
    if dry_run; then
        dry "write to $1: $2"
        return 0
    fi
    printf '%s\n' "$2" > "$1"
}

# append_line <path> <text>: add one line to the end of a file.
append_line() {
    if dry_run; then
        dry "append to $1: $2"
        return 0
    fi
    printf '%s\n' "$2" >> "$1"
}

# ---------------------------------------------------------------------------
# Safety checks
# ---------------------------------------------------------------------------

have_systemd() { [ -d /run/systemd/system ]; }

have_internet() { ping -c 1 -W 2 8.8.8.8 >/dev/null 2>&1; }

# need_cmd <command...>: stop with a clear message when a tool is missing.
need_cmd() {
    local cmd
    for cmd in "$@"; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            if dry_run; then
                warn "'${cmd}' is not installed here, so a real run would stop. Run ./setup.sh to install it."
            else
                error "'${cmd}' is not installed. Run ./setup.sh first."
                exit 1
            fi
        fi
    done
}

check_os() {
    local id="" like="" version=""
    if [ -r /etc/os-release ]; then
        id="$(sed -n 's/^ID=//p' /etc/os-release | head -n1 | tr -d '"')"
        like="$(sed -n 's/^ID_LIKE=//p' /etc/os-release | head -n1 | tr -d '"')"
        version="$(sed -n 's/^VERSION_ID=//p' /etc/os-release | head -n1 | tr -d '"')"
    fi
    case " ${id} ${like} " in
        *" ubuntu "* | *" debian "*) ;;
        *)
            if dry_run; then
                warn "This is not Ubuntu or Debian (found '${id:-unknown}'). A real run would stop here."
                return 0
            fi
            error "This lab only supports Ubuntu or Debian (found '${id:-unknown}')."
            exit 1
            ;;
    esac
    if [ "$id" = "ubuntu" ] && [ "$version" != "22.04" ] && [ "$version" != "24.04" ]; then
        warn "The lab is tested on Ubuntu 22.04 and 24.04. You are on ${version}; it should still work."
    fi
}

# check_systemd [name]: exit with code 2 when systemd is not running.
check_systemd() {
    local what="${1:-This scenario}"
    if have_systemd; then
        return 0
    fi
    if dry_run; then
        warn "systemd is not running here. ${what} needs it, so a real run would exit with code 2."
        return 0
    fi
    error "${what} needs systemd, but systemd is not running on this machine."
    error "This is common inside containers. Use a normal VM or a container that runs systemd."
    exit 2
}

require_root() {
    if dry_run; then
        return 0
    fi
    if [ "$(id -u)" -ne 0 ]; then
        error "This command changes the system, so it needs root. Run it again with sudo."
        exit 1
    fi
}

# confirm <question>: ask for a yes, unless --yes or --dry-run is active.
confirm() {
    local reply
    if [ "${LAB_YES:-0}" = "1" ] || dry_run; then
        return 0
    fi
    if [ ! -t 0 ]; then
        error "A confirmation is needed but there is no terminal. Run again with --yes."
        return 1
    fi
    read -r -p "$1 [y/N] " reply
    case "$reply" in
        y | Y | yes | YES) return 0 ;;
        *) return 1 ;;
    esac
}

# scenario_number <id>: 03-service-stopped -> 3
scenario_number() { printf '%d' "$((10#${1%%-*}))"; }

# ---------------------------------------------------------------------------
# State tracking: only one scenario may be active at a time
# ---------------------------------------------------------------------------

get_active() {
    if [ -r "$LAB_STATE_FILE" ]; then
        sed -n 's/^scenario=//p' "$LAB_STATE_FILE" | head -n1
    fi
}

get_active_started() {
    if [ -r "$LAB_STATE_FILE" ]; then
        sed -n 's/^started=//p' "$LAB_STATE_FILE" | head -n1
    fi
}

# is_active [id]: true when a scenario (or the given scenario) is active.
is_active() {
    local current
    current="$(get_active)"
    if [ -n "${1:-}" ]; then
        [ "$current" = "$1" ]
    else
        [ -n "$current" ]
    fi
}

set_active() {
    local id="$1" tmp
    if dry_run; then
        dry "mark scenario ${id} as active in ${LAB_STATE_FILE}"
        return 0
    fi
    mkdir -p "$LAB_STATE_DIR"
    chmod 755 "$LAB_STATE_DIR"
    tmp="${LAB_STATE_FILE}.tmp"
    printf 'scenario=%s\nstarted=%s\n' "$id" "$(date -u '+%Y-%m-%d %H:%M:%S UTC')" > "$tmp"
    mv -f -- "$tmp" "$LAB_STATE_FILE"
}

clear_active() {
    if dry_run; then
        dry "remove ${LAB_STATE_FILE}"
        return 0
    fi
    rm -f -- "$LAB_STATE_FILE"
}

# ---------------------------------------------------------------------------
# Backups: copies and notes are stored per scenario in /var/backups/troubleshooting-lab/
# ---------------------------------------------------------------------------

_backup_dir() { printf '%s/%s' "$LAB_BACKUP_DIR" "${SCENARIO_ID:-shared}"; }

_backup_name() {
    local path="${1#/}"
    printf '%s' "${path//\//__}"
}

backup_path() { printf '%s/%s' "$(_backup_dir)" "$(_backup_name "$1")"; }

has_backup() { [ -f "$(backup_path "$1")" ]; }

# backup_file <path>: copy a file once. A second call keeps the first (original) copy.
backup_file() {
    local src="$1" dest
    dest="$(backup_path "$src")"
    if dry_run; then
        dry "back up ${src} to ${dest}"
        return 0
    fi
    if [ -f "$dest" ]; then
        info "A backup of ${src} already exists, keeping the original copy."
        return 0
    fi
    if [ ! -e "$src" ]; then
        error "Cannot back up ${src}: the file does not exist."
        return 1
    fi
    mkdir -p "$(_backup_dir)"
    chmod 700 "$LAB_BACKUP_DIR"
    cp -L --preserve=mode,ownership,timestamps -- "$src" "$dest"
    ok "Backed up ${src}"
}

# restore_file <path>: write the backed up content back into the same file.
restore_file() {
    local dest="$1" src
    src="$(backup_path "$dest")"
    if dry_run; then
        dry "restore ${dest} from ${src}"
        return 0
    fi
    if [ ! -f "$src" ]; then
        error "No backup found for ${dest} (expected ${src})."
        return 1
    fi
    if [ -e "$dest" ]; then
        cat -- "$src" > "$dest"
        chmod --reference="$src" -- "$dest"
        chown --reference="$src" -- "$dest"
    else
        cp -p -- "$src" "$dest"
    fi
    ok "Restored ${dest} from the backup"
}

# note_set <key> <value> / note_get <key>: small facts about the original state.
note_set() {
    if dry_run; then
        dry "remember ${1}=${2}"
        return 0
    fi
    mkdir -p "$(_backup_dir)"
    chmod 700 "$LAB_BACKUP_DIR"
    printf '%s\n' "$2" > "$(_backup_dir)/note.${1}"
}

note_get() {
    local file
    file="$(_backup_dir)/note.${1}"
    if [ -r "$file" ]; then
        cat -- "$file"
    fi
}

clear_backups() {
    if dry_run; then
        dry "remove the backups in $(_backup_dir)"
        return 0
    fi
    rm -rf -- "$(_backup_dir)"
}

wipe_lab_state() {
    local dir
    for dir in "$LAB_STATE_DIR" "$LAB_BACKUP_DIR"; do
        case "$dir" in
            '' | / | /etc | /var | /var/lib | /var/backups | /root | /home | /usr)
                error "Refusing to delete '${dir}'."
                return 1
                ;;
        esac
        if dry_run; then
            dry "delete ${dir}"
        else
            rm -rf -- "$dir"
        fi
    done
}

# ---------------------------------------------------------------------------
# Auto-revert (scenarios 02 and 07) and recorded background processes (08 and 09)
# ---------------------------------------------------------------------------

# revert_seconds <default>: read LAB_REVERT_SECONDS, fall back to the default.
revert_seconds() {
    local value="${LAB_REVERT_SECONDS:-$1}"
    case "$value" in
        '' | *[!0-9]*)
            warn "LAB_REVERT_SECONDS must be a whole number. Using ${1}."
            value="$1"
            ;;
    esac
    if [ "$value" -lt 1 ]; then
        value="$1"
    fi
    printf '%s' "$value"
}

# cancel_revert <unit>: stop a pending auto-revert (timer or background job).
cancel_revert() {
    local unit="$1" pidfile pid children child
    pidfile="${LAB_STATE_DIR}/${unit}.pid"
    if dry_run; then
        dry "cancel any pending auto-revert (${unit})"
        return 0
    fi
    if have_systemd && command -v systemctl >/dev/null 2>&1; then
        systemctl stop "${unit}.timer" >/dev/null 2>&1 || true
        systemctl reset-failed "${unit}.service" >/dev/null 2>&1 || true
    fi
    if [ -r "$pidfile" ]; then
        pid="$(cat -- "$pidfile")"
        # Never kill ourselves: the background job runs fix.sh with the same PID.
        if [ -n "$pid" ] && [ "$pid" != "$$" ] && kill -0 "$pid" 2>/dev/null; then
            # Stop the parent first, so it cannot move on to the next command, then its children.
            children="$(pgrep -P "$pid" 2>/dev/null || true)"
            kill "$pid" 2>/dev/null || true
            for child in $children; do
                kill "$child" 2>/dev/null || true
            done
        fi
        rm -f -- "$pidfile"
    fi
}

cancel_all_reverts() {
    local unit
    for unit in lab-revert-02 lab-revert-07; do
        cancel_revert "$unit"
    done
}

# schedule_revert <seconds> <unit> <command...>: run a command later.
# Uses systemd-run and falls back to a background job when that is not possible.
schedule_revert() {
    local seconds="$1" unit="$2" at pid
    shift 2
    at="$(date -d "+${seconds} seconds" '+%H:%M:%S' 2>/dev/null || printf 'in %s seconds' "$seconds")"
    if dry_run; then
        dry "systemd-run --on-active=${seconds}s --unit=${unit} $*   (revert at about ${at})"
        return 0
    fi
    cancel_revert "$unit"
    mkdir -p "$LAB_STATE_DIR"
    if have_systemd && systemd-run --quiet --on-active="${seconds}s" --unit="$unit" \
        --setenv=LAB_YES=1 "$@" >/dev/null 2>&1; then
        ok "Auto-revert scheduled with systemd timer ${unit}.timer"
    else
        warn "systemd-run is not available. Using a background job instead."
        # shellcheck disable=SC2016 # $1 and $@ must be expanded by the inner bash, not by this shell
        nohup env LAB_YES=1 bash -c 'sleep "$1" || exit 0; shift; exec "$@"' lab-revert "$seconds" "$@" \
            >/dev/null 2>&1 &
        pid=$!
        printf '%s\n' "$pid" > "${LAB_STATE_DIR}/${unit}.pid"
        ok "Auto-revert scheduled as background job (PID ${pid})"
    fi
    bold "Everything will be put back automatically at ${at} (in ${seconds} seconds)."
}

# count_recorded_pids <pidfile> <text expected in the command line>
# Prints how many of the recorded processes are still running and still look right.
count_recorded_pids() {
    local pidfile="$1" pattern="$2" pid args count=0
    if [ -r "$pidfile" ]; then
        while IFS= read -r pid; do
            [ -n "$pid" ] || continue
            args="$(ps -o args= -p "$pid" 2>/dev/null || true)"
            case "$args" in
                *"$pattern"*) count=$((count + 1)) ;;
            esac
        done < "$pidfile"
    fi
    printf '%s' "$count"
}

# kill_recorded_pids <pidfile> <text expected in the command line>
# Stops only the processes that the lab recorded, and only if they still look right.
kill_recorded_pids() {
    local pidfile="$1" pattern="$2" pid args stopped=0
    if dry_run; then
        dry "stop the processes listed in ${pidfile}"
        return 0
    fi
    if [ ! -r "$pidfile" ]; then
        return 0
    fi
    while IFS= read -r pid; do
        [ -n "$pid" ] || continue
        args="$(ps -o args= -p "$pid" 2>/dev/null || true)"
        case "$args" in
            *"$pattern"*)
                pkill -TERM -P "$pid" 2>/dev/null || true
                kill -TERM "$pid" 2>/dev/null || true
                stopped=$((stopped + 1))
                ;;
        esac
    done < "$pidfile"
    rm -f -- "$pidfile"
    info "Stopped ${stopped} recorded process(es)."
}

# ---------------------------------------------------------------------------
# Shared flow for break.sh and fix.sh
# ---------------------------------------------------------------------------

# begin_break <id> <needs systemd: 0|1> <warning text>
begin_break() {
    local id="$1" needs_systemd="$2" message="$3" active
    check_os
    if [ "$needs_systemd" = "1" ]; then
        check_systemd "Scenario ${id}"
    fi
    require_root
    if dry_run; then
        info "Dry run: showing what would happen. Nothing will be changed."
    fi
    active="$(get_active)"
    if [ -n "$active" ] && [ "$active" != "$id" ]; then
        if dry_run; then
            warn "Scenario ${active} is still active, so a real break would be refused."
        else
            error "Scenario ${active} is still active."
            error "Fix it first with: ./lab.sh fix $(scenario_number "$active")   (or run: ./lab.sh reset)"
            exit 1
        fi
    fi
    if [ -z "$active" ] && ! dry_run; then
        clear_backups
    fi
    printf '\n'
    warn "$message"
    warn "Run this lab only in a disposable VM or container."
    if ! confirm "Break scenario ${id} now?"; then
        info "Cancelled. Nothing was changed."
        exit 1
    fi
}

# begin_fix <id> <needs systemd: 0|1>
begin_fix() {
    local id="$1" needs_systemd="$2" active
    check_os
    if [ "$needs_systemd" = "1" ]; then
        check_systemd "Scenario ${id}"
    fi
    require_root
    if dry_run; then
        info "Dry run: showing what would happen. Nothing will be changed."
    fi
    active="$(get_active)"
    if [ -z "$active" ]; then
        if dry_run; then
            warn "Scenario ${id} is not active, so a real fix would stop here. Showing the steps anyway."
        else
            info "Scenario ${id} is not active, so there is nothing to fix."
            exit 0
        fi
    elif [ "$active" != "$id" ]; then
        error "The active scenario is ${active}, not ${id}."
        error "Run: ./lab.sh fix $(scenario_number "$active")"
        exit 1
    fi
    FIX_FAILURES=0
    LAB_FIXING="$id"
    trap '_fix_notice' EXIT
}

# If a fix step stops unexpectedly, say so clearly instead of leaving a bare shell error.
_fix_notice() {
    local rc=$?
    if [ "$rc" -ne 0 ] && [ -n "${LAB_FIXING:-}" ]; then
        fail "Scenario ${LAB_FIXING} could not be fixed automatically (exit code ${rc}). Backups were kept."
        fail "Try again with ./lab.sh fix $(scenario_number "$LAB_FIXING"), or follow the manual fix in scenarios/${LAB_FIXING}/README.md."
    fi
}

# After set_active, arm a notice that explains how to recover if the break step stops early.
arm_failure_notice() {
    LAB_ARMED=1
    trap '_failure_notice' EXIT
}

disarm_failure_notice() { LAB_ARMED=0; }

_failure_notice() {
    local rc=$?
    if [ "$rc" -ne 0 ] && [ "$LAB_ARMED" = "1" ]; then
        error "The break step stopped early (exit code ${rc})."
        error "Run './lab.sh reset' to put everything back."
    fi
}

# print_ticket <text>: show the customer ticket after a break.
print_ticket() {
    local number
    number="$(scenario_number "$SCENARIO_ID")"
    printf '\n%s%s%s\n' "$C_BOLD" "Customer ticket" "$C_RESET"
    printf '  "%s"\n\n' "$1"
    printf 'Diagnose it like a support engineer. Need a nudge? ./lab.sh hint %s\n' "$number"
    printf 'Done? Put it back with: ./lab.sh fix %s\n' "$number"
}

# finish_break <summary>: close a successful break.
finish_break() {
    disarm_failure_notice
    if dry_run; then
        info "Dry run finished. Nothing was changed."
        return 0
    fi
    ok "Scenario ${SCENARIO_ID} is now active. $1"
}

# check <description> <command...>: run a verification and count failures.
check() {
    local description="$1"
    shift
    if dry_run; then
        dry "verify: ${description}"
        return 0
    fi
    if "$@" >/dev/null 2>&1; then
        ok "$description"
    else
        error "$description"
        FIX_FAILURES=$((FIX_FAILURES + 1))
    fi
}

# finish_fix <id>: print PASS or FAIL and clean up when everything is back to normal.
finish_fix() {
    LAB_FIXING=""
    if dry_run; then
        info "Dry run finished. Nothing was changed."
        return 0
    fi
    if [ "$FIX_FAILURES" -eq 0 ]; then
        clear_active
        clear_backups
        pass "Scenario ${1} is fixed. Everything is back to normal."
        return 0
    fi
    fail "Scenario ${1} is not fully fixed (${FIX_FAILURES} check(s) failed). Backups were kept so you can try again."
    return 1
}
