#!/usr/bin/env bash
# Scenario 02: put the original default route back.
set -euo pipefail

SCENARIO_ID="02-wrong-ip-gateway"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common.sh"

UNIT="lab-revert-02"

begin_fix "$SCENARIO_ID" 1
need_cmd ip

cancel_revert "$UNIT"

route="$(note_get default_route)"
bad_gw="$(note_get bad_gateway)"
iface="$(note_get interface)"
orig_gw="$(note_get orig_gateway)"
if [ -z "$route" ]; then
    if dry_run; then
        route="default via <original-gateway> dev <interface>"
        bad_gw="<bad-gateway>"
        iface="<interface>"
    else
        error "No saved default route was found, so it cannot be restored automatically."
        exit 1
    fi
fi

info "Restoring the default route: ${route}"
run ip route del default via "$bad_gw" dev "$iface" 2>/dev/null || true
read -r -a parts <<< "$route"
run ip route replace "${parts[@]}"

gateway_restored() {
    local now
    now="$(ip -4 route show default 2>/dev/null || true)"
    case "$now" in
        *"via ${orig_gw} "*) return 0 ;;
        *) return 1 ;;
    esac
}

check "The default route points to ${orig_gw} again" gateway_restored
if ! dry_run && ping -c 1 -W 2 "$orig_gw" >/dev/null 2>&1; then
    ok "The gateway ${orig_gw} answers ping"
fi

finish_fix "$SCENARIO_ID"
