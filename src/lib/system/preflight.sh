#!/usr/bin/env bash
# Pre-flight checks: disk space and battery charge.

: "${DISK_MIN_FREE_MB:=1024}"
: "${BATTERY_MIN_PCT:=20}"

# Power-supply directory read on Linux. Tests reassign it after sourcing,
# the environment never sets it.
SYS_POWER_DIR=/sys/class/power_supply

# Return 0 when running on battery: Linux AC adapters under SYS_POWER_DIR,
# else `pmset -g batt` on macOS. Unknown reads as "not on battery".
sys_is_on_battery() {
    if [[ -d $SYS_POWER_DIR ]]; then
        local adapter has_adapter=0
        for adapter in "$SYS_POWER_DIR"/A{C,DP,C0,DP0}*/online; do
            [[ -f $adapter ]] || continue
            has_adapter=1
            [[ $(cat "$adapter" 2>/dev/null) == 1 ]] && return 1
        done
        (( has_adapter )) && return 0
        return 1
    fi
    sys_has pmset || return 1
    local out; out=$(pmset -g batt 2>/dev/null || true)
    [[ $out == *"'Battery Power'"* ]]
}

# Print the battery charge in percent as decimal digits: first BAT* under
# SYS_POWER_DIR holding a number, else the first "N%" of `pmset -g batt`,
# else 100.
sys_battery_percent() {
    local capacity_file value
    for capacity_file in "$SYS_POWER_DIR"/BAT*/capacity; do
        [[ -f $capacity_file ]] || continue
        value=$(cat "$capacity_file" 2>/dev/null || true)
        [[ $value =~ ^[0-9]{1,3}$ ]] && { echo "$(( 10#$value ))"; return; }
    done
    if sys_has pmset; then
        local out; out=$(pmset -g batt 2>/dev/null || true)
        if [[ $out =~ [[:space:]]([0-9]+)%\; ]]; then
            echo "${BASH_REMATCH[1]}"; return
        fi
    fi
    echo 100
}

# Print the free MiB of the file system holding path $1 (default /), nothing
# when df fails.
disk_free_mb() {
    local path="${1:-/}"
    { df -Pm "$path" 2>/dev/null || true; } | awk 'NR==2{print $4}'
}

# Warn when / has less than DISK_MIN_FREE_MB free and, unless -y, exit 1
# when the user declines to continue. An unreadable figure skips the check.
disk_precheck() {
    local free; free=$(disk_free_mb /)
    [[ -z $free ]] && return 0
    if (( free < DISK_MIN_FREE_MB )); then
        ui_warn "Low disk space on / (${free}MB free, threshold ${DISK_MIN_FREE_MB}MB)."
        if (( ARG_YES == 0 )); then
            ui_confirm "Continue anyway?" n || { ui_muted "Aborted by user."; exit 1; }
        fi
    else
        log_info "disk precheck ok: ${free}MB free on /"
    fi
}

# Ask before updating on battery below BATTERY_MIN_PCT, unless -y.
battery_precheck() {
    sys_is_on_battery || return 0
    local percent; percent=$(sys_battery_percent)
    if (( percent < BATTERY_MIN_PCT )) && (( ! ARG_YES )); then
        ui_warn "On battery at ${percent}%. Updates are I/O heavy."
        ui_confirm "Continue anyway?" n || { ui_muted "Aborted."; exit 1; }
    fi
}
