#!/usr/bin/env bash
# Pre-update filesystem snapshot via snapper, timeshift or btrfs.

# Take a pre-update snapshot with the first tool that works: snapper (root
# config), timeshift, then a read-only btrfs snapshot of /. Return 1 when
# none worked, after naming each tool that failed and its exit code.
snapshot_create() {
    ui_title "Snapshot"
    local description
    description="eMerger pre-update $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if (( DRY_RUN )); then
        ui_sub "[dry-run] would create snapshot: $description"
        return 0
    fi
    local has_tried=0 rc
    if sys_has snapper && { snapper list-configs 2>/dev/null || true; } | grep -q '^root'; then
        has_tried=1; rc=0
        sys_as_root snapper -c root create --description "$description" --type single --cleanup-algorithm number || rc=$?
        if (( rc == 0 )); then
            ui_ok "snapper snapshot created"
            return 0
        fi
        ui_warn "snapper create failed (exit $rc)"
    fi
    if sys_has timeshift; then
        has_tried=1; rc=0
        sys_as_root timeshift --create --comments "$description" --tags D >/dev/null 2>&1 || rc=$?
        if (( rc == 0 )); then
            ui_ok "timeshift snapshot created"
            return 0
        fi
        ui_warn "timeshift --create failed (exit $rc)"
    fi
    if sys_has btrfs && { mount 2>/dev/null || true; } | grep -q 'on / type btrfs'; then
        has_tried=1; rc=0
        local snap_dir="/.snapshots/emerger"
        sys_as_root mkdir -p "$snap_dir" 2>/dev/null || true
        local name
        name="$snap_dir/$(date +%Y-%m-%dT%H-%M-%S)"
        sys_as_root btrfs subvolume snapshot -r / "$name" >/dev/null 2>&1 || rc=$?
        if (( rc == 0 )); then
            ui_ok "btrfs snapshot: $name"
            return 0
        fi
        ui_warn "btrfs subvolume snapshot failed (exit $rc)"
    fi
    (( has_tried )) || ui_err "No snapshot tool available (snapper/timeshift/btrfs)."
    return 1
}

# Roll back to the most recent eMerger snapshot with snapper (rollback) or
# timeshift (--restore). A raw btrfs snapshot needs a manual subvolume swap:
# print the path of the latest one and leave / untouched.
snapshot_rollback() {
    ui_title "Rollback"
    if sys_has snapper && { snapper list-configs 2>/dev/null || true; } | grep -q '^root'; then
        local last
        # Column 1 is "#", the number: keep its digits (snapper appends
        # markers such as "*" or "-"). Newer snapper draws "│" between columns.
        last=$({ snapper -c root list 2>/dev/null || true; } | sed 's/│/|/g' \
            | awk -F'|' '/eMerger pre-update/ {n = $1; gsub(/[^0-9]/, "", n); if (n != "") last = n} END{print last}')
        if [[ -n $last ]]; then
            ui_muted "Rolling back to snapper snapshot #$last"
            if (( DRY_RUN )); then
                ui_sub "[dry-run] would run: snapper -c root rollback $last"
                return 0
            fi
            if sys_as_root snapper -c root rollback "$last"; then
                ui_ok "Rollback queued. Reboot to apply."
                return 0
            fi
            ui_err "snapper rollback failed"; return 1
        fi
        ui_warn "No eMerger snapper snapshot found."
    fi
    if sys_has timeshift; then
        if (( DRY_RUN )); then
            ui_sub "[dry-run] would run: timeshift --restore (interactive)"
            return 0
        fi
        ui_muted "Launching timeshift --restore"
        sys_as_root timeshift --restore
        return $?
    fi
    if sys_has btrfs && { mount 2>/dev/null || true; } | grep -q 'on / type btrfs'; then
        local snap_dir="/.snapshots/emerger" latest
        if [[ -d $snap_dir ]]; then
            latest=$(ls -1t "$snap_dir" 2>/dev/null | head -n1)
            if [[ -n $latest ]]; then
                ui_warn "Latest btrfs snapshot: $snap_dir/$latest"
                ui_warn "Automatic btrfs rollback is not performed - swap subvolumes manually."
                return 1
            fi
        fi
    fi
    ui_err "No rollback mechanism available."
    return 1
}
