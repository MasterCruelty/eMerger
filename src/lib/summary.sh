#!/usr/bin/env bash
# Final summary: box banner, reboot advisory, optional package diff summary.

# Run state, never read from the environment.
SUMMARY_FREED_KB=0
SUMMARY_MANAGERS=()
SUMMARY_RESULTS=()
# Wall-clock seconds per manager, read back by estimate_for.
SUMMARY_SECONDS=()
SUMMARY_ERRORS=0

# Print KiB count $1 through numfmt in IEC units, one decimal and a B
# suffix ("1.5GB"), else as "<n> KiB" when numfmt is missing or fails.
_summary_format_bytes() {
    local kb="$1"
    if sys_has numfmt; then
        numfmt --to=iec --suffix=B --format='%.1f' $(( kb * 1024 )) 2>/dev/null && return
    fi
    printf '%s KiB' "$kb"
}

# Record manager $1 with result $2 (ok or fail) after $3 seconds.
summary_add() {
    SUMMARY_MANAGERS+=("$1"); SUMMARY_RESULTS+=("$2"); SUMMARY_SECONDS+=("${3:-0}")
    [[ $2 == ok ]] || SUMMARY_ERRORS=$(( SUMMARY_ERRORS + 1 ))
    return 0
}

# Print the run as one JSON line: the --json output and the history.jsonl entry.
summary_json() {
    local duration="$1"
    local i is_first=1
    printf '{"ts":"%s","duration":%d,"freed_kb":%d,"errors":%d,"reboot":%d,"managers":[' \
        "$(date -u +%Y-%m-%dT%H:%M:%SZ)" "$duration" "$SUMMARY_FREED_KB" "$SUMMARY_ERRORS" "${REBOOT_IS_NEEDED:-0}"
    for i in "${!SUMMARY_MANAGERS[@]}"; do
        (( is_first )) || printf ','
        is_first=0
        printf '{"name":"%s","result":"%s","secs":%d}' "${SUMMARY_MANAGERS[i]}" "${SUMMARY_RESULTS[i]}" "${SUMMARY_SECONDS[i]:-0}"
    done
    printf ']}\n'
}

# Close the run: check for a pending reboot, append the history line (not on
# a dry run), then print what the quiet level allows: the JSON line, a
# one-line tally (-qq), nothing (-qqq) or the summary box.
summary_print() {
    local duration="$1" line

    reboot_check
    line=$(summary_json "$duration")
    (( DRY_RUN )) || history_append "$line"

    if (( ARG_JSON )); then
        printf '%s\n' "$line"
        return
    fi

    (( QUIET_LEVEL >= 3 )) && return

    local min=$(( duration / 60 )) seconds=$(( duration % 60 ))
    local ok_count=0 fail_count=0 i
    for i in "${!SUMMARY_MANAGERS[@]}"; do
        if [[ ${SUMMARY_RESULTS[i]} == ok ]]; then
            ok_count=$(( ok_count + 1 ))
        else
            fail_count=$(( fail_count + 1 ))
        fi
    done

    _summary_lines "$min" "$seconds"

    if (( QUIET_LEVEL >= 2 )); then
        if (( SUMMARY_ERRORS > 0 )); then
            printf '%s/%s managers ok, %s error(s), %dm%02ds\n' \
                "$ok_count" "$(( ok_count + fail_count ))" "$SUMMARY_ERRORS" "$min" "$seconds"
        else
            printf '%s managers ok, %dm%02ds\n' "$ok_count" "$min" "$seconds"
        fi
        reboot_advisory
        return
    fi

    local UI_BOX_COLOR="$C_GREEN"
    # Read by ui_box.
    # shellcheck disable=SC2034
    (( SUMMARY_ERRORS > 0 )) && UI_BOX_COLOR="$C_YELLOW"
    ui_box "eMerger summary" "${_SUMMARY_LINES[@]}"

    reboot_advisory
}

# Set _SUMMARY_LINES to the summary box lines (managers, time $1 minutes $2
# seconds, freed space, changed packages, status). Reads the package diff
# unless this is a dry run.
_summary_lines() {
    local min="$1" seconds="$2" i
    local manager_list=""
    if (( ${#SUMMARY_MANAGERS[@]} > 0 )); then
        for i in "${!SUMMARY_MANAGERS[@]}"; do
            if [[ ${SUMMARY_RESULTS[i]} == ok ]]; then
                manager_list+="${C_GREEN}$(ui_glyph check)${C_RESET} ${SUMMARY_MANAGERS[i]}  "
            else
                manager_list+="${C_RED}$(ui_glyph cross)${C_RESET} ${C_RED}${SUMMARY_MANAGERS[i]}${C_RESET}  "
            fi
        done
        manager_list=${manager_list%  }
    fi

    local key_color="${C_DIM}${C_GRAY}"
    local time_line
    printf -v time_line '%s%-9s%s %s%dm%02ds%s' "$key_color" "time" "$C_RESET" "$C_BOLD" "$min" "$seconds" "$C_RESET"
    local freed_line=""
    (( SUMMARY_FREED_KB > 0 )) && printf -v freed_line '%s%-9s%s %s%s%s' "$key_color" "freed" "$C_RESET" "$C_CYAN" "$(_summary_format_bytes "$SUMMARY_FREED_KB")" "$C_RESET"
    local changed_line=""
    # Dry runs compute no diff: the file holds the last real run's.
    local changed_count=0
    (( DRY_RUN )) || changed_count=$(diff_count_changed 2>/dev/null || echo 0)
    (( changed_count > 0 )) && printf -v changed_line '%s%-9s%s %s packages  %s(up --changed)%s' "$key_color" "changed" "$C_RESET" "$changed_count" "$key_color" "$C_RESET"
    local err_line
    if (( SUMMARY_ERRORS > 0 )); then
        printf -v err_line '%s%-9s%s %s%s %s error(s)%s  %s(up --errors)%s' "$key_color" "status" "$C_RESET" "$C_YELLOW$C_BOLD" "$(ui_glyph warn)" "$SUMMARY_ERRORS" "$C_RESET" "$key_color" "$C_RESET"
    else
        printf -v err_line '%s%-9s%s %s%s all good%s' "$key_color" "status" "$C_RESET" "$C_GREEN$C_BOLD" "$(ui_glyph check)" "$C_RESET"
    fi

    local lines=()
    [[ -n $manager_list ]] && lines+=("$(printf '%s%-9s%s %s' "$key_color" "managers" "$C_RESET" "$manager_list")")
    lines+=("$time_line")
    [[ -n $freed_line ]]   && lines+=("$freed_line")
    [[ -n $changed_line ]] && lines+=("$changed_line")
    lines+=("$err_line")
    _SUMMARY_LINES=("${lines[@]}")
}
