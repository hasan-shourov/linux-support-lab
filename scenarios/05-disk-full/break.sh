#!/usr/bin/env bash
# Scenario 05: fill the disk with one big hidden file, always leaving 1 GB free.
set -euo pipefail

SCENARIO_ID="05-disk-full"
# shellcheck source-path=SCRIPTDIR/../..
# shellcheck source=lib/common.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/../../lib/common.sh"

BIGFILE="/var/tmp/.lab-bigfile"
RESERVE_MB=1024
MIN_MB=100
wanted_mb="${LAB_DISK_MB:-5120}"

case "$wanted_mb" in
    '' | *[!0-9]*)
        error "LAB_DISK_MB must be a whole number of megabytes (got '${wanted_mb}')."
        exit 1
        ;;
esac

free_mb="$(df -Pm /var/tmp | awk 'NR==2 {print $4}')"
size_mb=$((free_mb - RESERVE_MB))
if [ "$wanted_mb" -lt "$size_mb" ]; then
    size_mb="$wanted_mb"
fi
if [ "$size_mb" -lt 0 ]; then
    size_mb=0
fi
if [ "$size_mb" -lt "$MIN_MB" ] && [ ! -e "$BIGFILE" ]; then
    error "Not enough free space. The lab keeps 1 GB free and needs at least ${MIN_MB} MB to fill."
    error "Free space on /var/tmp is ${free_mb} MB, so the file would be ${size_mb} MB. Nothing was changed."
    exit 1
fi

begin_break "$SCENARIO_ID" 0 "This creates a hidden file of ${size_mb} MB in /var/tmp. At least 1 GB always stays free."

if [ -z "$(note_get free_mb_before)" ]; then
    note_set free_mb_before "$free_mb"
fi
note_set bigfile "$BIGFILE"

set_active "$SCENARIO_ID"
arm_failure_notice

if [ -e "$BIGFILE" ] && ! dry_run; then
    info "${BIGFILE} already exists, so nothing more is needed."
else
    info "Creating ${BIGFILE} (${size_mb} MB)"
    if ! run fallocate -l "${size_mb}M" "$BIGFILE"; then
        warn "fallocate does not work on this filesystem. Using dd instead (slower)."
        run dd if=/dev/zero of="$BIGFILE" bs=1M count="$size_mb" status=none
    fi
    run chmod 600 "$BIGFILE"
fi

if ! dry_run; then
    after_mb="$(df -Pm /var/tmp | awk 'NR==2 {print $4}')"
    ok "Free space on /var/tmp went from ${free_mb} MB to ${after_mb} MB"
fi

finish_break "Disk usage should be much higher now."
if ! dry_run; then
    print_ticket "Our server is almost out of disk space and the monitoring alert keeps firing. Nobody on the team knows what is using it. Please find it before the nightly backup fails."
fi
