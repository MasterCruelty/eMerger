#!/usr/bin/env bash
# Resume support: remember completed managers so an interrupted run can continue.

RESUME_FILE="$EMERGER_STATE/resume"

# Fill RESUME_DONE with the managers listed in RESUME_FILE, empty when it is
# missing.
resume_load() {
    RESUME_DONE=()
    [[ -f $RESUME_FILE ]] || return 0
    local line
    while IFS= read -r line || [[ -n $line ]]; do
        RESUME_DONE+=("$line")
    done <"$RESUME_FILE"
}

# Return 0 if manager $1 is in RESUME_DONE.
resume_has() {
    local manager="$1" entry
    for entry in "${RESUME_DONE[@]:-}"; do
        [[ $entry == "$manager" ]] && return 0
    done
    return 1
}

# Record manager $1 as done. A dry run leaves the cursor of real runs alone.
resume_mark() {
    local manager="$1"
    (( ${DRY_RUN:-0} )) && return 0
    printf '%s\n' "$manager" >>"$RESUME_FILE"
}

# Forget every completed manager (not on a dry run).
resume_clear() {
    (( ${DRY_RUN:-0} )) && return 0
    rm -f "$RESUME_FILE"
}
