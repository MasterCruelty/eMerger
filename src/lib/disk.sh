#!/usr/bin/env bash
# Disk-space precheck: warn/abort if the update target is tight.

: "${DISK_MIN_FREE_MB:=1024}"

disk_free_mb() {
    local path="${1:-/}"
    df -Pm "$path" 2>/dev/null | awk 'NR==2{print $4}'
}

disk_precheck() {
    local free; free=$(disk_free_mb /)
    [[ -z $free ]] && return 0
    if (( free < DISK_MIN_FREE_MB )); then
        ui_warn "Low disk space on / (${free}MB free, threshold ${DISK_MIN_FREE_MB}MB)."
        if (( ARG_YES == 0 )); then
            local ans
            read -r -p "    Continue anyway? [y/N]: " ans || ans=n
            [[ $ans == [yY]* ]] || { ui_muted "Aborted by user."; exit 1; }
        fi
    else
        log_info "disk precheck ok: ${free}MB free on /"
    fi
}
