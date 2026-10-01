#!/usr/bin/env bash
# Scenario 07: restore ~/.ssh and remove the lab SSH configuration.
set -euo pipefail

SCENARIO_ID="07-ssh-failure"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common.sh"

UNIT="lab-revert-07"
DROPIN="/etc/ssh/sshd_config.d/00-lab.conf"

begin_fix "$SCENARIO_ID" 1

cancel_revert "$UNIT"

# Ubuntu calls the service "ssh" (and "sshd" is only an alias). Some other systems use "sshd".
ssh_unit() {
    if systemctl cat ssh.service >/dev/null 2>&1 || ! systemctl cat sshd.service >/dev/null 2>&1; then
        echo ssh
    else
        echo sshd
    fi
}

ssh_dir="$(note_get ssh_dir)"
mode="$(note_get ssh_mode)"
owner="$(note_get ssh_owner)"
created="$(note_get ssh_created)"
if [ -z "$ssh_dir" ]; then
    if dry_run; then
        ssh_dir="<home>/.ssh"
        mode="<original-mode>"
        owner="<original-owner>"
    else
        error "No saved SSH settings were found, so they cannot be restored automatically."
        exit 1
    fi
fi

if [ "$created" = "yes" ]; then
    info "Removing ${ssh_dir} (the lab created it)"
    run rmdir --ignore-fail-on-non-empty "$ssh_dir"
    if [ -d "$ssh_dir" ]; then
        run chmod 700 "$ssh_dir"
    fi
else
    info "Restoring ${ssh_dir}: owner ${owner}, mode ${mode}"
    run chown "$owner" "$ssh_dir"
    run chmod "$mode" "$ssh_dir"
fi

if dry_run || [ -e "$DROPIN" ]; then
    info "Removing the lab SSH configuration ${DROPIN}"
    run rm -f -- "$DROPIN"
    run sshd -t
    run systemctl reload "$(ssh_unit)"
fi

ssh_dir_ok() {
    if [ "$created" = "yes" ]; then
        [ ! -d "$ssh_dir" ] || [ "$(stat -c '%a' "$ssh_dir")" = "700" ]
    else
        [ "$(stat -c '%a' "$ssh_dir")" = "$mode" ]
    fi
}
dropin_gone() { [ ! -e "$DROPIN" ]; }
sshd_config_valid() { ! command -v sshd >/dev/null 2>&1 || sshd -t; }

check "${ssh_dir} permissions are back to normal" ssh_dir_ok
check "The lab SSH drop-in is removed" dropin_gone
check "sshd accepts its configuration" sshd_config_valid

finish_fix "$SCENARIO_ID"
