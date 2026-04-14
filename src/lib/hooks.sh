#!/usr/bin/env bash
# Run user hook scripts from $EMERGER_CONFIG/hooks/{pre,post}.d/*.sh

hooks_run() {
    local phase="$1"
    local dir="$EMERGER_CONFIG/hooks/${phase}.d"
    [[ -d $dir ]] || return 0
    local h ran=0
    for h in "$dir"/*.sh; do
        [[ -f $h ]] || continue
        (( ran == 0 )) && ui_title "Hooks ($phase)"
        ran=1
        ui_sub "$(basename "$h")"
        if (( DRY_RUN )); then continue; fi
        if ! bash "$h"; then
            ui_warn "hook $(basename "$h") failed"
            log_warn "hook $phase/$h failed"
        fi
    done
}
