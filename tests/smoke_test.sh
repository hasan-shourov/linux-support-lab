#!/usr/bin/env bash
# tests/smoke_test.sh - break -> verify symptom -> fix -> verify recovery
# for the scenarios that are safe on any systemd machine: 03, 06, 09 and 10.
# It also dry-runs all ten scenarios. It exits non-zero if anything fails.
set -euo pipefail

TESTS_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LAB="${TESTS_DIR}/../lab.sh"
FAILURES=0

pass_msg() { printf '  PASS  %s\n' "$*"; }
fail_msg() {
    printf '  FAIL  %s\n' "$*"
    FAILURES=$((FAILURES + 1))
}

# expect <description> <command...>: the command must succeed.
expect() {
    local description="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        pass_msg "$description"
    else
        fail_msg "$description"
    fi
}

# expect_not <description> <command...>: the command must fail.
expect_not() {
    local description="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        fail_msg "$description"
    else
        pass_msg "$description"
    fi
}

# step <description> <command...>: run a lab command, count a failure and carry on.
step() {
    local description="$1"
    shift
    if "$@" >/dev/null 2>&1; then
        pass_msg "$description"
    else
        fail_msg "$description"
    fi
}

http_code() { curl -s -o /dev/null -w '%{http_code}' --max-time 5 http://localhost || true; }
site_ok() { [ "$(http_code)" = "200" ]; }
site_forbidden() { [ "$(http_code)" = "403" ]; }
site_down() { ! curl -s -o /dev/null --max-time 3 http://localhost; }
nginx_active() { systemctl is-active --quiet nginx; }
port80_busy() { [ -n "$(ss -ltnH 'sport = :80' 2>/dev/null || true)" ]; }
# getent ahostsv4 uses the same lookup path as curl and ping (plain 'getent hosts' asks for IPv6 first)
hosts_bad() { grep -q '203.0.113.10' <<< "$(getent ahostsv4 example.com || true)"; }

echo "== Dry run of all ten scenarios (changes nothing)"
for n in 1 2 3 4 5 6 7 8 9 10; do
    expect "break ${n} --dry-run" "$LAB" break "$n" --dry-run
done
expect "list" "$LAB" list
expect "--help" "$LAB" --help

if [ ! -d /run/systemd/system ]; then
    echo
    echo "SKIPPED the real break and fix tests: systemd is not running on this machine."
    echo "Run this test on a normal Ubuntu VM to check scenarios 03, 06, 09 and 10."
    if [ "$FAILURES" -gt 0 ]; then
        echo "Result: ${FAILURES} check(s) failed."
        exit 1
    fi
    echo "Result: dry-run checks passed."
    exit 0
fi

if [ "$(id -u)" -ne 0 ]; then
    echo "The real tests change the system and need root. Run: sudo ./tests/smoke_test.sh" >&2
    exit 1
fi

for tool in nginx curl ss; do
    if ! command -v "$tool" >/dev/null 2>&1; then
        echo "'${tool}' is missing. Run ./setup.sh first." >&2
        exit 1
    fi
done

status_text="$("$LAB" status 2>&1 || true)"
if grep -q 'Active scenario' <<< "$status_text"; then
    echo "A scenario is already active. Run './lab.sh reset' first." >&2
    exit 1
fi

# Always leave the machine clean, even if a check fails.
trap '"$LAB" reset --yes >/dev/null 2>&1 || true' EXIT

echo
echo "== Scenario 03: service stopped"
expect "site works before" site_ok
step "lab.sh break 3" "$LAB" break 3 --yes
expect_not "nginx is no longer active" nginx_active
expect "site is down" site_down
expect_not "a second scenario is refused while 03 is active" "$LAB" break 10 --yes
step "lab.sh fix 3" "$LAB" fix 3
expect "nginx is active again" nginx_active
expect "site works again" site_ok

echo
echo "== Scenario 06: permission denied"
step "lab.sh break 6" "$LAB" break 6 --yes
expect "site returns 403" site_forbidden
step "lab.sh fix 6" "$LAB" fix 6
expect "site returns 200 again" site_ok

echo
echo "== Scenario 09: port conflict"
step "lab.sh break 9" "$LAB" break 9 --yes
expect_not "nginx is not running" nginx_active
expect "another program holds port 80" port80_busy
step "lab.sh fix 9" "$LAB" fix 9
expect "nginx is running again" nginx_active
expect "site works again" site_ok

echo
echo "== Scenario 10: bad hosts entry"
step "lab.sh break 10" "$LAB" break 10 --yes
expect "example.com resolves to the wrong address" hosts_bad
step "lab.sh fix 10" "$LAB" fix 10
expect_not "example.com no longer resolves to the wrong address" hosts_bad

echo
if [ "$FAILURES" -gt 0 ]; then
    echo "Result: ${FAILURES} check(s) failed."
    exit 1
fi
echo "Result: all checks passed."
