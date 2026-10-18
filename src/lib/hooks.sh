#!/usr/bin/env bash
# Run user hook scripts from $EMERGER_CONFIG/hooks/{pre,post}.d/*.sh

# Run every trusted hook of phase $1 (pre or post) in name order. A hook
# failing, or refused by trust_file, is a warning, never an abort. Under
# --json a hook's stdout goes to stderr, so stdout holds the JSON alone.
hooks_run() {
    local phase="$1" out_fd=1
    (( ${ARG_JSON:-0} )) && out_fd=2
    local dir="$EMERGER_CONFIG/hooks/${phase}.d"
    [[ -d $dir ]] || return 0
    local hook has_run=0
    for hook in "$dir"/*.sh; do
        [[ -f $hook ]] || continue
        (( has_run == 0 )) && ui_title "Hooks ($phase)"
        has_run=1
        ui_sub "$(basename "$hook")"
        if (( DRY_RUN )); then continue; fi
        trust_file "$hook" || continue
        if ! bash "$hook" 9>&- >&"$out_fd"; then
            ui_warn "hook $(basename "$hook") failed"
            log_warn "hook $phase/$hook failed"
        fi
    done
}
