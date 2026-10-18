#!/usr/bin/env bash
# Module loader of the bash half: source it with `all`, or with the modules
# to load. A name is a module path under src/lib (`ui/term`), a directory
# (`ui`, every module in it) or a file stem (`term`). Modules load in the
# order of _LOAD_MODULES whatever the order of the names. An unknown name
# loads nothing and returns 1.

# Every module, in load order.
_LOAD_MODULES=(
    ui/term ui/text ui/print ui/monitor ui/prompt knobs log sys
    managers/progress state/estimate
    run/command run/select run/parallel run/sudo args ignore
    managers/registry managers/detect managers/icon managers/recipes
    clean/size clean/cache clean/trash clean/deep hooks selfupdate autoupdate
    system/notify system/rpi managers/rpi_eeprom system/reboot state/diff
    system/preflight system/snapshot system/mirrors state/resume state/lock
    doctor managers/changelog profiles summary state/history quiet_hours
    managers/plugins state/metrics trust
)

_load_dir=${BASH_SOURCE[0]%/*}
_load_names=("$@")
for _load_name in "${_load_names[@]}"; do
    [[ $_load_name == all ]] && continue
    _load_hit=0
    for _load_module in "${_LOAD_MODULES[@]}"; do
        if [[ $_load_name == "$_load_module" || $_load_name == "${_load_module%%/*}" \
              || $_load_name == "${_load_module##*/}" ]]; then
            _load_hit=1
        fi
    done
    if (( ! _load_hit )); then
        printf 'load.sh: unknown module %s\n' "$_load_name" >&2
        unset _load_dir _load_names _load_name _load_hit _load_module
        return 1
    fi
done
for _load_module in "${_LOAD_MODULES[@]}"; do
    for _load_name in "${_load_names[@]}"; do
        if [[ $_load_name == all || $_load_name == "$_load_module" \
              || $_load_name == "${_load_module%%/*}" || $_load_name == "${_load_module##*/}" ]]; then
            # shellcheck source=/dev/null
            source "$_load_dir/$_load_module.sh"
            break
        fi
    done
done
unset _load_dir _load_names _load_name _load_hit _load_module
