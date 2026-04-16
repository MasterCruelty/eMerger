#!/usr/bin/env bash
# Profile loader. Profiles are bash snippets that set ARG_* defaults.
# Search order:
#   1) $EMERGER_CONFIG/profiles.d/<name>.sh  (user)
#   2) $EMERGER_ROOT/share/profiles/<name>.sh (shipped)

profile_load() {
    local name="$1"
    [[ -z $name ]] && return 0
    if [[ ! $name =~ ^[A-Za-z0-9._-]+$ ]]; then
        printf 'Invalid profile name: "%s" (allowed: letters, digits, dot, dash, underscore)\n' "$name" >&2
        exit 2
    fi
    local candidates=(
        "$EMERGER_CONFIG/profiles.d/${name}.sh"
        "$EMERGER_ROOT/share/profiles/${name}.sh"
    )
    local f
    for f in "${candidates[@]}"; do
        if [[ -f $f ]]; then
            # shellcheck disable=SC1090
            source "$f"
            log_info "profile loaded: $name ($f)"
            return 0
        fi
    done
    printf 'Profile "%s" not found. Looked in:\n' "$name" >&2
    printf '  %s\n' "${candidates[@]}" >&2
    exit 2
}

profile_list() {
    ui_title "Available profiles"
    local seen=() p n
    for dir in "$EMERGER_CONFIG/profiles.d" "$EMERGER_ROOT/share/profiles"; do
        [[ -d $dir ]] || continue
        for p in "$dir"/*.sh; do
            [[ -f $p ]] || continue
            n=$(basename "$p" .sh)
            local dup=0 s
            for s in "${seen[@]:-}"; do [[ $s == "$n" ]] && dup=1; done
            (( dup )) && continue
            seen+=("$n")
            local desc=""
            desc=$(grep -m1 '^# description:' "$p" 2>/dev/null | sed 's/^# description:[[:space:]]*//' || true)
            printf '  %s%s%s  %s%s%s\n' "$C_CYAN" "$n" "$C_RESET" "$C_GRAY" "$desc" "$C_RESET"
        done
    done
}
