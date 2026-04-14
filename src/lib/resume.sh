#!/usr/bin/env bash
# Resume support: remember completed managers so an interrupted run can continue.

: "${RESUME_FILE:=$EMERGER_STATE/resume}"

resume_load() {
    RESUME_DONE=()
    [[ -f $RESUME_FILE ]] || return 0
    local line
    while IFS= read -r line || [[ -n $line ]]; do
        RESUME_DONE+=("$line")
    done <"$RESUME_FILE"
}

resume_has() {
    local m="$1" x
    for x in "${RESUME_DONE[@]:-}"; do
        [[ $x == "$m" ]] && return 0
    done
    return 1
}

resume_mark() {
    local m="$1"
    printf '%s\n' "$m" >>"$RESUME_FILE"
}

resume_clear() {
    rm -f "$RESUME_FILE"
}
