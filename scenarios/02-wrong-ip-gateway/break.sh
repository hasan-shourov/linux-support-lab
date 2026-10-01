#!/usr/bin/env bash
# Scenario 02: send the default route to a gateway that does not exist (runtime only).
set -euo pipefail

SCENARIO_ID="02-wrong-ip-gateway"
SCENARIO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh
source "${SCENARIO_DIR}/../../lib/common.sh"

UNIT="lab-revert-02"

begin_break "$SCENARIO_ID" 1 "This points the default route at a gateway that does not exist. It is reverted automatically."
need_cmd ip

# Save the original default route once. A second run keeps the first record.
route="$(note_get default_route)"
if [ -z "$route" ]; then
    route="$(ip -4 route show default 2>/dev/null | head -n1 || true)"
    if [ -z "$route" ]; then
        if dry_run; then
            warn "No default route found here. Using an example route for the dry run."
            route="default via 10.0.2.2 dev eth0 proto dhcp src 10.0.2.15 metric 100"
        else
            error "There is no default route, so there is nothing to break."
            exit 1
        fi
    fi
    info "Original default route: ${route}"
    note_set default_route "$route"
fi

read -r -a parts <<< "$route"
orig_gw="" iface="" metric=""
for ((i = 0; i < ${#parts[@]}; i++)); do
    case "${parts[$i]}" in
        via) orig_gw="${parts[$((i + 1))]:-}" ;;
        dev) iface="${parts[$((i + 1))]:-}" ;;
        metric) metric="${parts[$((i + 1))]:-}" ;;
    esac
done

if ! [[ "$orig_gw" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]] || [ -z "$iface" ]; then
    error "The default route has no IPv4 gateway or interface, so it cannot be simulated safely."
    exit 1
fi

# An unused address in the same /24: the original gateway with the last octet 253.
bad_gw="${orig_gw%.*}.253"
if [ "$bad_gw" = "$orig_gw" ]; then
    bad_gw="${orig_gw%.*}.252"
fi
note_set orig_gateway "$orig_gw"
note_set bad_gateway "$bad_gw"
note_set interface "$iface"

delay="$(revert_seconds 120)"

set_active "$SCENARIO_ID"
arm_failure_notice

# The safety net comes first: even if this script dies, the route comes back.
schedule_revert "$delay" "$UNIT" "${SCENARIO_DIR}/fix.sh"

# Keeping the original metric makes the new route replace the old one instead of sitting next to it.
if [ -n "$metric" ]; then
    run ip route replace default via "$bad_gw" dev "$iface" onlink metric "$metric"
else
    run ip route replace default via "$bad_gw" dev "$iface" onlink
fi

if ! dry_run; then
    ok "Default route now points to ${bad_gw} (original: ${orig_gw})"
    warn "If you are connected over SSH from another network, your session may freeze until the revert."
fi

finish_break "The internet should be unreachable now."
if ! dry_run; then
    print_ticket "Hello, the server suddenly has no internet. We can still reach other machines in the office network, but updates and external websites time out. This is blocking a release."
fi
