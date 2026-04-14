#!/usr/bin/env bash
# Ignore list: packages that should never be upgraded.
# File: $EMERGER_CONFIG/ignore.list (one pattern per line, # comments allowed)
# Native support: pacman (--ignore). Others: advisory only.

: "${IGNORE_FILE:=$EMERGER_CONFIG/ignore.list}"
IGNORE_LIST=()

ignore_load() {
    IGNORE_LIST=()
    [[ -f $IGNORE_FILE ]] || return 0
    local line
    while IFS= read -r line; do
        line="${line%%#*}"
        line="${line//[[:space:]]/}"
        [[ -z $line ]] && continue
        IGNORE_LIST+=("$line")
    done <"$IGNORE_FILE"
}

ignore_pacman_flag() {
    (( ${#IGNORE_LIST[@]} == 0 )) && return
    local joined; joined=$(IFS=,; printf '%s' "${IGNORE_LIST[*]}")
    printf -- '--ignore=%s' "$joined"
}

ignore_advisory() {
    (( ${#IGNORE_LIST[@]} == 0 )) && return 0
    ui_muted "Ignore list: ${IGNORE_LIST[*]}"
    if ! sys_has pacman; then
        ui_muted "(only pacman honors --ignore natively; hold the rest via apt-mark/dnf versionlock)"
    fi
}
