#!/usr/bin/env bash
# Trash emptying, after a prompt unless -y.

# Empty the user's Trash after a prompt: the freedesktop Trash on Linux,
# ~/.Trash on macOS (no info directory there).
clean_trash() {
    local files="$HOME/.local/share/Trash/files"
    local info="$HOME/.local/share/Trash/info"
    if sys_is_macos; then files="$HOME/.Trash"; info=""; fi
    ui_title "Trash"
    if [[ ! -d $files ]]; then
        ui_ok "empty"; return 0
    fi
    local listing count=0 rc=0
    listing=$(find "$files" -mindepth 1 -maxdepth 1 2>/dev/null) || rc=$?
    [[ -n $listing ]] && count=$(wc -l <<<"$listing")
    if (( count == 0 && rc != 0 )); then
        # macOS denies ~/.Trash to a terminal without Full Disk Access.
        if sys_is_macos; then
            ui_warn "cannot read the Trash (macOS privacy settings)"
        else
            ui_warn "cannot read the Trash"
        fi
        return 0
    fi
    if (( count == 0 )); then
        ui_ok "empty"; return 0
    fi
    local size; size=$(_clean_size_human "$files")
    ui_muted "$files"
    if ui_confirm "Empty trash?" n "($size, $count items)"; then
        local before; before=$(_clean_size_kb "$files")
        if (( DRY_RUN )); then
            ui_sub "[dry-run] would empty trash"
        else
            find "$files" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null || true
            [[ -n $info && -d $info ]] && find "$info" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null || true
        fi
        local after freed; after=$(_clean_size_kb "$files")
        freed=$(( before - after ))
        (( freed < 0 )) && freed=0
        SUMMARY_FREED_KB=$(( SUMMARY_FREED_KB + freed ))
        ui_done "trash emptied" "$size"
    else
        ui_muted "skipped"
    fi
}
