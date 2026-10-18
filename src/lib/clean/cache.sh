#!/usr/bin/env bash
# User cache cleaning: a menu of ~/.cache entries, biggest first. Prompts
# before deleting unless -y.

# ~/.cache entries to leave alone (names or globs). ~/.cache/emerger is
# always kept.
: "${CACHE_EXCLUDE:=}"
: "${CACHE_MENU_ROWS:=12}"

# Return 0 if ~/.cache entry name $1 is kept: emerger always, else any
# glob of CACHE_EXCLUDE (comma, space or tab separated) that matches it.
_clean_is_excluded() {
    local name="$1" pattern
    [[ $name == emerger ]] && return 0
    local -a patterns=()
    # read -a splits without pathname expansion: a pattern never globs the cwd.
    IFS=$', \t\n' read -r -a patterns <<<"$CACHE_EXCLUDE"
    for pattern in ${patterns[@]+"${patterns[@]}"}; do
        # shellcheck disable=SC2053
        [[ $name == $pattern ]] && return 0
    done
    return 1
}

# Parse "1 3 5-7", "a" or "n" against a menu of $2 rows into _CLEAN_PICK:
# 1-based, ascending, each row once. Numbers are decimal (leading zeros
# allowed), out-of-range rows are dropped.
_clean_parse_pick() {
    local input="$1" max="$2" token first last i
    _CLEAN_PICK=()
    input=${input//,/ }
    case "${input,,}" in
        a|all|'*') for (( i=1; i<=max; i++ )); do _CLEAN_PICK+=("$i"); done; return 0 ;;
        ''|n|none|no) return 0 ;;
    esac
    local -a seen=() tokens=()
    IFS=$' \t' read -r -a tokens <<<"$input"
    for token in ${tokens[@]+"${tokens[@]}"}; do
        if [[ $token =~ ^([0-9]+)-([0-9]+)$ ]]; then
            first=$(( 10#${BASH_REMATCH[1]} )); last=$(( 10#${BASH_REMATCH[2]} ))
        elif [[ $token =~ ^[0-9]+$ ]]; then
            first=$(( 10#$token )); last=$first
        else
            continue
        fi
        (( first < 1 )) && first=1
        (( last > max )) && last=$max
        for (( i=first; i<=last; i++ )); do seen[i]=1; done
    done
    for i in "${!seen[@]}"; do _CLEAN_PICK+=("$i"); done
    return 0
}

# Offer the ~/.cache entries as a numbered menu, biggest first, and remove
# the rows picked (all of them under -y). Adds the space freed to SUMMARY_FREED_KB.
clean_cache() {
    local target="$HOME/.cache"
    if [[ ! -d $target ]]; then
        ui_title "User cache"; ui_ok "empty"; return 0
    fi

    # Biggest first, one du for everything.
    local -a names=() sizes=() kept=()
    local total=0
    _clean_cache_scan "$target"

    ui_section "" "User cache" "$(_clean_format_kb "$total")"
    if (( ${#names[@]} == 0 )) || (( total < 64 )); then
        ui_ok "already clean"; return 0
    fi

    local -a menu_names=() menu_sizes=() menu_paths=()
    _clean_cache_menu

    local max=${menu_sizes[0]} row_count=${#menu_names[@]}
    (( max < 1 )) && max=1
    if (( QUIET_LEVEL < 1 )) && (( ! ARG_YES )); then
        _clean_cache_print
    fi

    local pick
    if (( ARG_YES )); then
        pick=all
    else
        ui_ask "Clean which?" "a/N" "a = all, n = none, or numbers like 1 3 5-7" || true
        pick=$UI_ANSWER
    fi
    _clean_parse_pick "$pick" "$row_count"
    if (( ${#_CLEAN_PICK[@]} == 0 )); then
        ui_muted "skipped"; return 0
    fi

    _clean_cache_remove "$target"
}

# Fill clean_cache's names, sizes (KiB) and kept with the entries of cache
# directory $1, biggest first, and add their sizes to its total. Excluded
# entries go to kept, entries under 16 KiB are left out.
_clean_cache_scan() {
    local target="$1" kb path name
    while IFS=$'\t' read -r kb path; do
        [[ -z $path ]] && continue
        name=${path##*/}
        if _clean_is_excluded "$name"; then kept+=("$name"); continue; fi
        (( kb < 16 )) && continue
        names+=("$name"); sizes+=("$kb"); total=$(( total + kb ))
    done < <(du -sk -- "$target"/* "$target"/.[!.]* 2>/dev/null | sort -rn)
    return 0
}

# Fill clean_cache's menu_names, menu_sizes and menu_paths from its names
# and sizes: the first CACHE_MENU_ROWS rows, the rest lumped into one
# "N others" row whose path lists them separated by "/", which no entry name holds.
_clean_cache_menu() {
    local rows=${#names[@]} i
    (( rows > CACHE_MENU_ROWS )) && rows=$CACHE_MENU_ROWS
    for (( i=0; i<rows; i++ )); do
        menu_names+=("${names[i]}"); menu_sizes+=("${sizes[i]}"); menu_paths+=("${names[i]}")
    done
    if (( ${#names[@]} > rows )); then
        local rest=0 rest_list=""
        for (( i=rows; i<${#names[@]}; i++ )); do
            rest=$(( rest + sizes[i] )); rest_list+="${names[i]}/"
        done
        menu_names+=("$(( ${#names[@]} - rows )) others"); menu_sizes+=("$rest"); menu_paths+=("$rest_list")
    fi
}

# Print clean_cache's menu, one bar per row scaled to its max, then the
# kept entries.
_clean_cache_print() {
    local i
    for (( i=0; i<row_count; i++ )); do
        ui_bar $(( menu_sizes[i] * 100 / max ))
        printf '    %s%2d%s  %-24.24s %s %s%6s%s\n' "$C_MAGENTA" $(( i + 1 )) "$C_RESET" \
            "${menu_names[i]}" "$_UI_BAR" "$C_BOLD" "$(_clean_format_kb "${menu_sizes[i]}")" "$C_RESET"
    done
    if (( ${#kept[@]} > 0 )); then
        local kept_text; printf -v kept_text '%s ' "${kept[@]}"
        ui_muted "kept: ${kept_text% }"
    fi
}

# Remove the rows of clean_cache's menu picked in _CLEAN_PICK from cache
# directory $1 (listed only under --dry-run) and add the space freed to
# SUMMARY_FREED_KB.
_clean_cache_remove() {
    local target="$1"
    local before freed=0 row part
    before=$(_clean_size_kb "$target")
    local -a parts=()
    for row in "${_CLEAN_PICK[@]}"; do
        IFS=/ read -r -a parts <<<"${menu_paths[row-1]}"
        for part in "${parts[@]}"; do
            [[ -z $part ]] && continue
            if (( DRY_RUN )); then
                ui_sub "[dry-run] would remove $target/$part"
            else
                rm -rf -- "${target:?}/$part" 2>/dev/null || true
            fi
        done
    done
    if (( ! DRY_RUN )); then
        freed=$(( before - $(_clean_size_kb "$target") ))
        (( freed < 0 )) && freed=0
        SUMMARY_FREED_KB=$(( SUMMARY_FREED_KB + freed ))
    fi
    ui_done "cache cleaned" "${#_CLEAN_PICK[@]} item(s), $(_clean_format_kb "$freed")"
}
