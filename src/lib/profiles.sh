#!/usr/bin/env bash
# Profile loader. Profiles are bash snippets that set ARG_* defaults.
# Search order:
#   1) $EMERGER_CONFIG/profiles.d/<name>.sh  (user)
#   2) $EMERGER_ROOT/share/profiles/<name>.sh (shipped)

# Source profile $1 from the first directory that has it. Exit 2 when the
# name is invalid, no file exists, or the user file fails trust_file.
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
    local file
    for file in "${candidates[@]}"; do
        if [[ -f $file ]]; then
            # Shipped profiles are part of the checkout being run.
            if [[ $file == "$EMERGER_CONFIG/"* ]] && ! trust_file "$file"; then
                exit 2
            fi
            # shellcheck disable=SC1090
            source "$file" || true
            log_info "profile loaded: $name ($file)"
            return 0
        fi
    done
    printf 'Profile "%s" not found. Looked in:\n' "$name" >&2
    printf '  %s\n' "${candidates[@]}" >&2
    exit 2
}

# Print every profile name with its "# description:" line, user profiles
# first and a shipped one only when no user file has its name.
profile_list() {
    ui_title "Available profiles"
    local seen=() file name
    for dir in "$EMERGER_CONFIG/profiles.d" "$EMERGER_ROOT/share/profiles"; do
        [[ -d $dir ]] || continue
        for file in "$dir"/*.sh; do
            [[ -f $file ]] || continue
            name=$(basename "$file" .sh)
            local is_seen=0 seen_name
            for seen_name in "${seen[@]:-}"; do [[ $seen_name == "$name" ]] && is_seen=1; done
            (( is_seen )) && continue
            seen+=("$name")
            local desc=""
            desc=$(grep -m1 '^# description:' "$file" 2>/dev/null | sed 's/^# description:[[:space:]]*//' || true)
            printf '  %s%s%s  %s%s%s\n' "$C_CYAN" "$name" "$C_RESET" "$C_GRAY" "$desc" "$C_RESET"
        done
    done
}
