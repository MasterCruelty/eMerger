#!/usr/bin/env bash
# Ignore list: packages that should never be upgraded.
# File: $EMERGER_CONFIG/ignore.list (one pattern per line, # comments allowed)
# Native support: pacman (--ignore). Others: advisory only.

IGNORE_FILE="$EMERGER_CONFIG/ignore.list"
IGNORE_LIST=()

# Fill IGNORE_LIST from IGNORE_FILE: one pattern per line, text after # and
# all whitespace dropped. Empty when the file is missing.
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

# Print the pacman --ignore=a,b option for IGNORE_LIST, nothing when empty.
ignore_pacman_flag() {
    (( ${#IGNORE_LIST[@]} == 0 )) && return
    local joined; joined=$(IFS=,; printf '%s' "${IGNORE_LIST[*]}")
    printf -- '--ignore=%s' "$joined"
}

# Print IGNORE_LIST and, without pacman, that the other managers need their
# own hold command.
ignore_advisory() {
    (( ${#IGNORE_LIST[@]} == 0 )) && return 0
    ui_muted "Ignore list: ${IGNORE_LIST[*]}"
    if ! sys_has pacman; then
        ui_muted "(only pacman honors --ignore natively; hold the rest via apt-mark/dnf versionlock)"
    fi
}
