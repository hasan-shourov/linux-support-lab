#!/usr/bin/env bash
# Scenario 04: enable UFW (keeping SSH open) and block port 80/tcp.
set -euo pipefail

SCENARIO_ID="04-firewall-blocking"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common.sh"

begin_break "$SCENARIO_ID" 1 "This turns on the UFW firewall (SSH stays open) and blocks port 80/tcp."
need_cmd ufw

# Record the original firewall state once. A second run keeps the first record.
if [ -z "$(note_get ufw_was_active)" ]; then
    status_text="$(ufw status 2>/dev/null || true)"
    added_rules="$(ufw show added 2>/dev/null || true)"
    app_list="$(ufw app list 2>/dev/null || true)"

    if grep -q '^Status: active' <<< "$status_text"; then
        note_set ufw_was_active yes
    else
        note_set ufw_was_active no
    fi
    if grep -Eq '^ufw (allow|limit) (OpenSSH|22(/tcp)?)$' <<< "$added_rules"; then
        note_set ssh_rule_existed yes
    else
        note_set ssh_rule_existed no
    fi
    if grep -Eq '^ufw deny 80(/tcp)?$' <<< "$added_rules"; then
        note_set deny_rule_existed yes
    else
        note_set deny_rule_existed no
    fi
    if grep -Eq '^ufw allow 80(/tcp)?$' <<< "$added_rules"; then
        note_set allow80_existed yes
    else
        note_set allow80_existed no
    fi
    if grep -q 'OpenSSH' <<< "$app_list"; then
        note_set ssh_rule OpenSSH
    else
        note_set ssh_rule 22/tcp
    fi
fi

ssh_rule="$(note_get ssh_rule)"
ssh_rule="${ssh_rule:-OpenSSH}"

set_active "$SCENARIO_ID"
arm_failure_notice

# SSH is allowed before the firewall is enabled, so you cannot lock yourself out.
info "Allowing SSH (${ssh_rule}) first so your session stays alive"
run ufw allow "$ssh_rule"
info "Enabling the firewall"
run ufw --force enable
info "Blocking port 80/tcp (inserted as rule 1, so it wins over any existing allow rule)"
run ufw insert 1 deny 80/tcp

if ! dry_run; then
    info "Checking the break. UFW always allows loopback, so 'curl localhost' still works. That is expected."
    numbered="$(ufw status numbered)"
    printf '%s\n' "$numbered"
    if ! grep -q '80/tcp.*DENY' <<< "$numbered"; then
        error "The deny rule for 80/tcp is missing."
        exit 1
    fi
    ok "UFW now denies 80/tcp"
    if command -v iptables >/dev/null 2>&1; then
        rules="$(iptables -L -n 2>/dev/null || true)"
        if grep -q 'dpt:80' <<< "$rules"; then
            ok "iptables shows a rule for port 80"
        fi
    fi
fi

finish_break "The site should time out from other machines."
if ! dry_run; then
    print_ticket "Hi, our website works when we test on the server itself, but customers and my laptop only see a spinning page that never loads. It started after the security hardening yesterday."
fi
