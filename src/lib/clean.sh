#!/usr/bin/env bash
# Cache and trash cleaners. Safe-by-default: prompt unless -y.

_clean_size_kb() {
    [[ -d "$1" ]] || { echo 0; return; }
    du -sk "$1" 2>/dev/null | awk '{print $1}'
}

_clean_confirm() {
    local prompt="$1"
    if (( ARG_YES )); then echo y; return; fi
    local ans
    read -r -p "    $prompt [y/N]: " ans || ans=n
    printf '%s' "$ans"
}

clean_cache() {
    local target="$HOME/.cache"
    ui_title "User cache"
    if [[ ! -d $target ]]; then
        ui_ok "empty"; return 0
    fi
    local size; size=$(du -sh "$target" 2>/dev/null | cut -f1)
    ui_muted "$target  ($size)"
    local ans; ans=$(_clean_confirm "Clean user cache?")
    if [[ $ans == [yY]* ]]; then
        local before; before=$(_clean_size_kb "$target")
        if (( DRY_RUN )); then
            ui_sub "[dry-run] would remove contents of $target"
        else
            find "$target" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null || true
        fi
        local after; after=$(_clean_size_kb "$target")
        SUMMARY_FREED=$(( SUMMARY_FREED + before - after ))
        ui_ok "cache cleaned"
    else
        ui_muted "skipped"
    fi
}

clean_trash() {
    local files="$HOME/.local/share/Trash/files"
    local info="$HOME/.local/share/Trash/info"
    ui_title "Trash"
    if [[ ! -d $files ]]; then
        ui_ok "empty"; return 0
    fi
    local count
    count=$(find "$files" -mindepth 1 -maxdepth 1 2>/dev/null | wc -l)
    if (( count == 0 )); then
        ui_ok "empty"; return 0
    fi
    local size; size=$(du -sh "$files" 2>/dev/null | cut -f1)
    ui_muted "$files  ($size, $count items)"
    local ans; ans=$(_clean_confirm "Empty trash?")
    if [[ $ans == [yY]* ]]; then
        local before; before=$(_clean_size_kb "$files")
        if (( DRY_RUN )); then
            ui_sub "[dry-run] would empty trash"
        else
            find "$files" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null || true
            [[ -d $info ]] && find "$info" -mindepth 1 -maxdepth 1 -exec rm -rf -- {} + 2>/dev/null || true
        fi
        local after; after=$(_clean_size_kb "$files")
        SUMMARY_FREED=$(( SUMMARY_FREED + before - after ))
        ui_ok "trash emptied"
    else
        ui_muted "skipped"
    fi
}
