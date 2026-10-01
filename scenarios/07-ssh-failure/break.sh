#!/usr/bin/env bash
# Scenario 07: break SSH key login by making ~/.ssh too open (StrictModes rejects it).
# Optional: --with-password-disable also turns off SSH password login.
set -euo pipefail

SCENARIO_ID="07-ssh-failure"
SCENARIO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh
source "${SCENARIO_DIR}/../../lib/common.sh"

UNIT="lab-revert-07"
DROPIN="/etc/ssh/sshd_config.d/00-lab.conf" # starts with 00 because sshd uses the first value it finds
WITH_PASSWORD_DISABLE=0

for arg in "$@"; do
    case "$arg" in
        --with-password-disable) WITH_PASSWORD_DISABLE=1 ;;
        *)
            error "Unknown option: ${arg}"
            exit 1
            ;;
    esac
done

# Ubuntu calls the service "ssh" (and "sshd" is only an alias). Some other systems use "sshd".
ssh_unit() {
    if systemctl cat ssh.service >/dev/null 2>&1 || ! systemctl cat sshd.service >/dev/null 2>&1; then
        echo ssh
    else
        echo sshd
    fi
}

user="${SUDO_USER:-root}"
home="$(getent passwd "$user" | cut -d: -f6 || true)"
if [ -z "$home" ]; then
    error "Could not find the home directory of user '${user}'."
    exit 1
fi
ssh_dir="${home}/.ssh"

message="This makes ${ssh_dir} writable by everyone, so sshd refuses key login for ${user}."
if [ "$WITH_PASSWORD_DISABLE" = "1" ]; then
    message="${message} It also turns off SSH password login."
fi
begin_break "$SCENARIO_ID" 1 "$message"
if [ "$WITH_PASSWORD_DISABLE" = "1" ]; then
    need_cmd sshd
fi

printf '\n'
bold "KEEP A SECOND SSH SESSION OPEN while you try this scenario. Do not close it."
printf '\n'

# Record the original state once. A second run keeps the first record.
if [ -z "$(note_get ssh_dir)" ]; then
    note_set ssh_user "$user"
    note_set ssh_dir "$ssh_dir"
    if [ -d "$ssh_dir" ]; then
        note_set ssh_created no
        note_set ssh_mode "$(stat -c '%a' "$ssh_dir")"
        note_set ssh_owner "$(stat -c '%U:%G' "$ssh_dir")"
        info "Original: ${ssh_dir} has mode $(stat -c '%a' "$ssh_dir")"
    else
        note_set ssh_created yes
    fi
fi

delay="$(revert_seconds 600)"

set_active "$SCENARIO_ID"
arm_failure_notice

# The safety net comes first: even if this script dies, SSH comes back.
schedule_revert "$delay" "$UNIT" "${SCENARIO_DIR}/fix.sh"

if [ ! -d "$ssh_dir" ]; then
    info "${ssh_dir} does not exist yet. Creating it for the simulation."
    run install -d -m 700 -o "$user" -g "$(id -gn "$user" 2>/dev/null || echo "$user")" "$ssh_dir"
fi
run chmod 777 "$ssh_dir"

if [ "$WITH_PASSWORD_DISABLE" = "1" ]; then
    write_file "$DROPIN" "# Written by troubleshooting-lab (scenario 07). Removed by ./lab.sh fix 7"
    append_line "$DROPIN" "PasswordAuthentication no"
    # Never reload sshd with a configuration that does not validate.
    if ! run sshd -t; then
        error "sshd rejected the configuration. Removing the lab drop-in and stopping."
        rm -f -- "$DROPIN"
        exit 1
    fi
    run systemctl reload "$(ssh_unit)"
fi

if ! dry_run; then
    ok "${ssh_dir} is now mode $(stat -c '%a' "$ssh_dir")"
    if command -v sshd >/dev/null 2>&1 && grep -qi '^strictmodes no' <<< "$(sshd -T 2>/dev/null || true)"; then
        warn "StrictModes is off on this machine, so key login may keep working. That is not the usual setup."
    fi
fi

finish_break "Key login for ${user} should be refused now."
if ! dry_run; then
    print_ticket "Hi team, I cannot log in to the server over SSH with my key since this morning. It worked yesterday and I did not change my keys. I need to deploy today, so this is quite urgent."
fi
