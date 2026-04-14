#!/usr/bin/env bash
# Final summary: box banner, reboot advisory, optional package diff summary.

: "${SUMMARY_FREED:=0}"
SUMMARY_MANAGERS=()
SUMMARY_RESULTS=()
SUMMARY_ERRORS=0

_fmt_bytes() {
    local kb="$1"
    if sys_has numfmt; then
        numfmt --to=iec --suffix=B --format='%.1f' $(( kb * 1024 )) 2>/dev/null && return
    fi
    printf '%s KiB' "$kb"
}

summary_json() {
    local duration="$1"
    local i first=1
    printf '{"ts":"%s","duration":%d,"freed_kb":%d,"errors":%d,"reboot":%d,"managers":[' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$duration" "$SUMMARY_FREED" "$SUMMARY_ERRORS" "${REBOOT_NEEDED:-0}"
    for i in "${!SUMMARY_MANAGERS[@]}"; do
        (( first )) || printf ','
        first=0
        printf '{"name":"%s","result":"%s"}' "${SUMMARY_MANAGERS[i]}" "${SUMMARY_RESULTS[i]}"
    done
    printf ']}\n'
}

summary_print() {
    local duration="$1"

    if (( ARG_JSON )); then
        reboot_check
        summary_json "$duration"
        _persist_history "$duration"
        return
    fi

    (( QUIET_LEVEL >= 3 )) && return

    local min=$(( duration / 60 )) s=$(( duration % 60 ))
    local ok_count=0 fail_count=0 i
    for i in "${!SUMMARY_MANAGERS[@]}"; do
        if [[ ${SUMMARY_RESULTS[i]} == ok ]]; then
            ok_count=$(( ok_count + 1 ))
        else
            fail_count=$(( fail_count + 1 ))
        fi
    done

    local mgr_list=""
    if (( ${#SUMMARY_MANAGERS[@]} > 0 )); then
        for i in "${!SUMMARY_MANAGERS[@]}"; do
            if [[ ${SUMMARY_RESULTS[i]} == ok ]]; then
                mgr_list+="${C_GREEN}$(ui_glyph check)${C_RESET} ${SUMMARY_MANAGERS[i]}  "
            else
                mgr_list+="${C_RED}$(ui_glyph cross)${C_RESET} ${SUMMARY_MANAGERS[i]}  "
            fi
        done
    fi

    local dur_line="duration: ${min}m${s}s"
    local freed_line=""
    (( SUMMARY_FREED > 0 )) && freed_line="freed:    $(_fmt_bytes "$SUMMARY_FREED")"
    local changed_line=""
    local changed_n; changed_n=$(diff_count_changed 2>/dev/null || echo 0)
    (( changed_n > 0 )) && changed_line="pkg diff: ${changed_n} changes (up --changed)"
    local err_line
    if (( SUMMARY_ERRORS > 0 )); then
        err_line="${C_YELLOW}${SUMMARY_ERRORS} error(s) - up --errors${C_RESET}"
    else
        err_line="${C_GREEN}no errors${C_RESET}"
    fi

    if (( QUIET_LEVEL >= 2 )); then
        if (( SUMMARY_ERRORS > 0 )); then
            printf '%s/%s managers ok, %s error(s), %dm%02ds\n' \
                "$ok_count" "$(( ok_count + fail_count ))" "$SUMMARY_ERRORS" "$min" "$s"
        else
            printf '%s managers ok, %dm%02ds\n' "$ok_count" "$min" "$s"
        fi
        _persist_history "$duration"
        reboot_check; reboot_advisory
        return
    fi

    local lines=("$dur_line")
    [[ -n $freed_line ]]   && lines+=("$freed_line")
    [[ -n $changed_line ]] && lines+=("$changed_line")
    lines+=("$err_line")
    [[ -n $mgr_list ]] && lines=("$mgr_list" "" "${lines[@]}")

    ui_box "eMerger summary" "${lines[@]}"

    reboot_check
    reboot_advisory

    _persist_history "$duration"
}

_persist_history() {
    local duration="$1"
    {
        printf '{"ts":"%s","duration":%d,"freed_kb":%d,"errors":%d,"reboot":%d,"managers":[' \
            "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$duration" "$SUMMARY_FREED" "$SUMMARY_ERRORS" "${REBOOT_NEEDED:-0}"
        local first=1 i
        for i in "${!SUMMARY_MANAGERS[@]}"; do
            (( first )) || printf ','
            first=0
            printf '{"name":"%s","result":"%s"}' "${SUMMARY_MANAGERS[i]}" "${SUMMARY_RESULTS[i]}"
        done
        printf ']}\n'
    } >>"$EMERGER_STATE/history.jsonl" 2>/dev/null || true

    local hist="$EMERGER_STATE/history.jsonl"
    if [[ -f $hist ]] && [[ $(wc -l <"$hist") -gt 500 ]]; then
        tail -n 500 "$hist" >"$hist.tmp" && mv "$hist.tmp" "$hist"
    fi
}

show_errors() {
    local log="$EMERGER_LOG"
    if [[ ! -f $log ]]; then
        ui_ok "No log yet."
        return 0
    fi
    local count
    count=$(grep -c '|ERROR|' "$log" 2>/dev/null || true)
    : "${count:=0}"
    if (( count == 0 )); then
        ui_ok "No errors logged."
    else
        ui_warn "$count error line(s) in $log:"
        grep '|ERROR|' "$log" | tail -n 30 | progress_highlight | sed 's/^/  /'
    fi
}

show_history() {
    local hist="$EMERGER_STATE/history.jsonl"
    if [[ ! -f $hist ]]; then
        ui_muted "No history yet."
        return
    fi
    ui_title "Recent runs"
    tail -n 10 "$hist" | while IFS= read -r line; do
        local ts dur err reboot
        ts=$(printf '%s' "$line" | sed -n 's/.*"ts":"\([^"]*\)".*/\1/p')
        dur=$(printf '%s' "$line" | sed -n 's/.*"duration":\([0-9]*\).*/\1/p')
        err=$(printf '%s' "$line" | sed -n 's/.*"errors":\([0-9]*\).*/\1/p')
        reboot=$(printf '%s' "$line" | sed -n 's/.*"reboot":\([0-9]*\).*/\1/p')
        local tag=""
        [[ ${reboot:-0} -gt 0 ]] && tag=" ${C_YELLOW}reboot${C_RESET}"
        if [[ ${err:-0} -gt 0 ]]; then
            printf '  %s%s%s %s  %ss  %serrors=%s%s%s\n' "$C_RED" "$(ui_glyph cross)" "$C_RESET" "$ts" "$dur" "$C_YELLOW" "$err" "$C_RESET" "$tag"
        else
            printf '  %s%s%s %s  %ss%s\n' "$C_GREEN" "$(ui_glyph check)" "$C_RESET" "$ts" "$dur" "$tag"
        fi
    done
}
