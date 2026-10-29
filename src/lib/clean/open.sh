#!/usr/bin/env bash
# Disk space held by deleted files a running process still keeps open
# (Linux): reported in the cache step, freed only when the holder closes
# them or exits.

# /proc read by the scan, a variable so a test can point it at a missing one.
: "${_CLEAN_PROC:=/proc}"

# Rows of the report: the biggest holders, the rest left out.
CLEAN_OPEN_ROWS=5

# Report the deleted files the processes readable here keep open on the
# filesystems of / and $HOME, per command, biggest first, when they hold 1M
# or more.
# Each file counts once, however many descriptors point at it. Silent
# without /proc (macOS).
clean_open_deleted() {
    [[ -d $_CLEAN_PROC/self/fd ]] || return 0
    local devs fd pid dev ino blocks unit kb comm
    devs=" $(stat -c %d / 2>/dev/null || true) $(stat -c %d "$HOME" 2>/dev/null || true) "
    local -A seen=() held=()
    while IFS= read -r -d '' fd; do
        IFS='|' read -r dev ino blocks unit < <(stat -L -c '%d|%i|%b|%B' -- "$fd" 2>/dev/null) || continue
        [[ $devs == *" $dev "* ]] || continue
        [[ -n ${seen[$dev:$ino]:-} ]] && continue
        seen[$dev:$ino]=1
        kb=$(( blocks * unit / 1024 ))
        pid=${fd#"$_CLEAN_PROC"/}
        pid=${pid%%/*}
        comm=$(cat "$_CLEAN_PROC/$pid/comm" 2>/dev/null) || comm="pid $pid"
        held[$comm]=$(( ${held[$comm]:-0} + kb ))
    done < <(find "$_CLEAN_PROC"/[0-9]*/fd -mindepth 1 -maxdepth 1 -lname '*(deleted)' -print0 2>/dev/null)

    local total=0
    for comm in "${!held[@]}"; do total=$(( total + held[$comm] )); done
    (( total >= 1024 )) || return 0
    ui_info "$(_clean_format_kb "$total") held by deleted files still open, freed when their holders close"
    while IFS=$'\t' read -r kb comm; do
        ui_sub "$(printf '%-24.24s %6s' "$comm" "$(_clean_format_kb "$kb")")"
    done < <(for comm in "${!held[@]}"; do printf '%s\t%s\n' "${held[$comm]}" "$comm"; done \
        | sort -rn | head -n "$CLEAN_OPEN_ROWS")
    return 0
}
