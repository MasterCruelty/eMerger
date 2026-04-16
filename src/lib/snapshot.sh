#!/usr/bin/env bash
# Pre-update filesystem snapshot via snapper, timeshift or btrfs.

snapshot_create() {
    ui_title "Snapshot"
    local desc="eMerger pre-update $(date -u +%Y-%m-%dT%H:%M:%SZ)"
    if (( DRY_RUN )); then
        ui_sub "[dry-run] would create snapshot: $desc"
        return 0
    fi
    if sys_has snapper && snapper list-configs 2>/dev/null | grep -q '^root'; then
        if sudo snapper -c root create --description "$desc" --type single --cleanup-algorithm number; then
            ui_ok "snapper snapshot created"
            return 0
        fi
    fi
    if sys_has timeshift; then
        if sudo timeshift --create --comments "$desc" --tags D >/dev/null 2>&1; then
            ui_ok "timeshift snapshot created"
            return 0
        fi
    fi
    if sys_has btrfs && mount | grep -q 'on / type btrfs'; then
        local snap_dir="/.snapshots/emerger"
        sudo mkdir -p "$snap_dir" 2>/dev/null || true
        local name="$snap_dir/$(date +%Y-%m-%dT%H-%M-%S)"
        if sudo btrfs subvolume snapshot -r / "$name" >/dev/null 2>&1; then
            ui_ok "btrfs snapshot: $name"
            return 0
        fi
    fi
    ui_warn "No snapshot tool available (snapper/timeshift/btrfs); continuing without."
    return 1
}

# Roll back to the most recent eMerger-created snapshot.
# Supports snapper (native rollback) and timeshift (--restore).
# For raw btrfs snapshots the user must swap subvolumes manually - we print
# the path of the latest one and refuse to touch /.
snapshot_rollback() {
    ui_title "Rollback"
    if sys_has snapper && snapper list-configs 2>/dev/null | grep -q '^root'; then
        local last
        last=$(snapper -c root list 2>/dev/null | awk -F'|' '/eMerger pre-update/ {gsub(/ /,"",$2); last=$2} END{print last}')
        if [[ -n $last ]]; then
            ui_muted "Rolling back to snapper snapshot #$last"
            if (( DRY_RUN )); then
                ui_sub "[dry-run] would run: snapper -c root rollback $last"
                return 0
            fi
            if sudo snapper -c root rollback "$last"; then
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
        sudo timeshift --restore
        return $?
    fi
    if sys_has btrfs && mount | grep -q 'on / type btrfs'; then
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
