#!/usr/bin/env bash
# Scenario 04: remove the deny rule and restore the original UFW state.
set -euo pipefail

SCENARIO_ID="04-firewall-blocking"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common.sh"

begin_fix "$SCENARIO_ID" 1
need_cmd ufw

was_active="$(note_get ufw_was_active)"
ssh_existed="$(note_get ssh_rule_existed)"
deny_existed="$(note_get deny_rule_existed)"
allow80_existed="$(note_get allow80_existed)"
ssh_rule="$(note_get ssh_rule)"
ssh_rule="${ssh_rule:-OpenSSH}"

if [ "$deny_existed" != "yes" ]; then
    info "Deleting the deny rule for 80/tcp"
    run ufw --force delete deny 80/tcp
    if [ "$allow80_existed" = "yes" ]; then
        info "Putting back the allow rule for 80/tcp that existed before"
        run ufw allow 80/tcp
    fi
fi
if [ "$ssh_existed" != "yes" ]; then
    info "Deleting the SSH rule the lab added (${ssh_rule})"
    run ufw --force delete allow "$ssh_rule"
fi
if [ "$was_active" != "yes" ]; then
    info "UFW was inactive before the lab, so turning it off again"
    run ufw --force disable
fi

deny_rule_gone() {
    local rules
    rules="$(ufw status numbered 2>/dev/null || true)"
    ! grep -q '80/tcp.*DENY' <<< "$rules"
}

original_state_back() {
    local status_text
    status_text="$(ufw status 2>/dev/null || true)"
    if [ "$was_active" = "yes" ]; then
        grep -q '^Status: active' <<< "$status_text"
    else
        grep -q '^Status: inactive' <<< "$status_text"
    fi
}

if [ "$deny_existed" != "yes" ]; then
    check "The deny rule for 80/tcp is gone" deny_rule_gone
fi
check "UFW is back to its original state (active: ${was_active:-unknown})" original_state_back

finish_fix "$SCENARIO_ID"
