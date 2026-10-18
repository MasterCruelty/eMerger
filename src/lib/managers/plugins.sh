#!/usr/bin/env bash
# External package-manager plugins: *.sh files in ~/.config/emerger/managers.d/
# that set PM_PLUGIN_SLUG and define pm_<slug>_detect and pm_<slug>_run, plus the
# optional pm_<slug>_{needs_sudo,parallel,dev,security,icon} queries. A file not
# owned by the user, or writable by group or other, is not loaded (trust_file).
# Template: share/plugins/example.sh.

PLUGIN_SLUGS=()

# Source every trusted managers.d/*.sh and register each one that sets
# PM_PLUGIN_SLUG and defines its detect and run functions. Others are warned about.
plugins_load() {
    local dir="$EMERGER_CONFIG/managers.d"
    [[ -d $dir ]] || return 0
    local file slug
    for file in "$dir"/*.sh; do
        [[ -e $file ]] || continue
        trust_file "$file" || continue
        PM_PLUGIN_SLUG=""
        # shellcheck disable=SC1090
        source "$file" || { ui_warn "plugin $file failed to load"; continue; }
        slug="$PM_PLUGIN_SLUG"
        if [[ -z $slug ]]; then
            ui_warn "plugin $file did not set PM_PLUGIN_SLUG"; continue
        fi
        if ! declare -F "pm_${slug}_detect" >/dev/null; then
            ui_warn "plugin $slug: missing pm_${slug}_detect"; continue
        fi
        if ! declare -F "pm_${slug}_run" >/dev/null; then
            ui_warn "plugin $slug: missing pm_${slug}_run"; continue
        fi
        PLUGIN_SLUGS+=("$slug")
        PKG_MANAGERS+=("$slug")
    done
}

# Return 0 if name $1 is a registered plugin slug.
plugin_is() {
    local name="$1" slug
    for slug in "${PLUGIN_SLUGS[@]}"; do
        [[ $slug == "$name" ]] && return 0
    done
    return 1
}

# Return 0 if plugin $1 defines pm_<slug>_needs_sudo and it answers yes.
plugin_needs_sudo() {
    declare -F "pm_${1}_needs_sudo" >/dev/null && "pm_${1}_needs_sudo"
}
# Return 0 if plugin $1 defines pm_<slug>_parallel and it answers yes.
plugin_is_parallel() {
    declare -F "pm_${1}_parallel" >/dev/null && "pm_${1}_parallel"
}
# Return 0 if plugin $1 defines pm_<slug>_security and it answers yes.
plugin_has_security() {
    declare -F "pm_${1}_security" >/dev/null && "pm_${1}_security"
}
# Return 0 if plugin $1 defines pm_<slug>_dev and it answers yes.
plugin_is_dev() {
    declare -F "pm_${1}_dev" >/dev/null && "pm_${1}_dev"
}
# Return 0 if plugin $1 reports its tool installed. Lock fd 9 is closed for it.
plugin_detect() {
    "pm_${1}_detect" 9>&-
}
# Run plugin $1. Under --json its stdout goes to stderr, so stdout holds
# the JSON line alone.
plugin_run() {
    if (( ${ARG_JSON:-0} )); then
        "pm_${1}_run" 9>&- >&2
    else
        "pm_${1}_run" 9>&-
    fi
}
# Print plugin $1's pm_<slug>_icon, or a bullet when it defines none.
plugin_icon() {
    if declare -F "pm_${1}_icon" >/dev/null; then
        "pm_${1}_icon"
    else
        printf '%s' "$(ui_glyph bullet)"
    fi
}
