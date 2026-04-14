#!/usr/bin/env bash
# External package-manager plugins.
#
# A plugin is a *.sh file in ~/.config/emerger/managers.d/ that defines,
# at minimum, three functions named after its slug <SLUG>:
#
#   pm_<slug>_detect        -> return 0 if the manager is present
#   pm_<slug>_run           -> perform refresh/upgrade/clean, return 0/non-0
#
# And optionally:
#
#   pm_<slug>_needs_sudo    -> return 0 if the manager needs elevation
#   pm_<slug>_parallel      -> return 0 if it's safe to run in parallel
#   pm_<slug>_dev           -> return 0 if it belongs to --dev
#   pm_<slug>_icon          -> print a short glyph
#
# The plugin must also declare its slug via:
#
#   PM_PLUGIN_SLUG=<slug>
#
# when sourced. Example plugin at share/plugins/example.sh.

PLUGIN_SLUGS=()

plugins_load() {
    local dir="$EMERGER_CONFIG/managers.d"
    [[ -d $dir ]] || return 0
    local f slug
    for f in "$dir"/*.sh; do
        [[ -e $f ]] || continue
        PM_PLUGIN_SLUG=""
        # shellcheck disable=SC1090
        source "$f" || { ui_warn "plugin $f failed to load"; continue; }
        slug="$PM_PLUGIN_SLUG"
        if [[ -z $slug ]]; then
            ui_warn "plugin $f did not set PM_PLUGIN_SLUG"; continue
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

plugin_is() {
    local name="$1" s
    for s in "${PLUGIN_SLUGS[@]}"; do
        [[ $s == "$name" ]] && return 0
    done
    return 1
}

plugin_needs_sudo() {
    declare -F "pm_${1}_needs_sudo" >/dev/null && "pm_${1}_needs_sudo"
}
plugin_is_parallel() {
    declare -F "pm_${1}_parallel" >/dev/null && "pm_${1}_parallel"
}
plugin_is_dev() {
    declare -F "pm_${1}_dev" >/dev/null && "pm_${1}_dev"
}
plugin_detect() {
    "pm_${1}_detect"
}
plugin_run() {
    "pm_${1}_run"
}
plugin_icon() {
    if declare -F "pm_${1}_icon" >/dev/null; then
        "pm_${1}_icon"
    else
        printf '%s' "$(ui_glyph bullet)"
    fi
}
