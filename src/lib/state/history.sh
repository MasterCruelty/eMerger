#!/usr/bin/env bash
# Run history in $EMERGER_STATE/history.jsonl: append and show.

# Append JSON line $1 to history.jsonl, keeping the last 500 lines.
history_append() {
    printf '%s\n' "$1" >>"$EMERGER_STATE/history.jsonl" 2>/dev/null || true

    local history="$EMERGER_STATE/history.jsonl"
    if [[ -f $history ]] && [[ $(wc -l <"$history") -gt 500 ]]; then
        tail -n 500 "$history" >"$history.tmp" && mv "$history.tmp" "$history"
    fi
}

# Print the last 10 runs of history.jsonl, one line each: time, duration,
# error count and a reboot tag.
history_show() {
    local history="$EMERGER_STATE/history.jsonl"
    if [[ ! -f $history ]]; then
        ui_muted "No history yet."
        return
    fi
    ui_title "Recent runs"
    tail -n 10 "$history" | while IFS= read -r line; do
        local timestamp duration errors reboot
        timestamp=$(history_text "$line" ts)
        duration=$(history_field "$line" duration)
        errors=$(history_field "$line" errors)
        reboot=$(history_field "$line" reboot)
        local tag=""
        [[ ${reboot:-0} -gt 0 ]] && tag=" ${C_YELLOW}reboot${C_RESET}"
        if [[ ${errors:-0} -gt 0 ]]; then
            printf '  %s%s%s %s  %ss  %serrors=%s%s%s\n' "$C_RED" "$(ui_glyph cross)" "$C_RESET" "$timestamp" "$duration" "$C_YELLOW" "$errors" "$C_RESET" "$tag"
        else
            printf '  %s%s%s %s  %ss%s\n' "$C_GREEN" "$(ui_glyph check)" "$C_RESET" "$timestamp" "$duration" "$tag"
        fi
    done
}

# Print number field $2 of history line $1 ("duration", "errors", ...),
# empty when the line has none.
history_field() {
    printf '%s' "$1" | sed -n "s/.*\"$2\":\([0-9]*\).*/\1/p"
}

# Print string field $2 of history line $1 ("ts", "name", "result"), empty
# when the line has none.
history_text() {
    printf '%s' "$1" | sed -n "s/.*\"$2\":\"\([^\"]*\)\".*/\1/p"
}
