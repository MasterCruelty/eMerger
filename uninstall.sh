#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck source=src/lib/ui.sh
source "$REPO_DIR/src/lib/ui.sh"
# shellcheck source=src/lib/sys.sh
source "$REPO_DIR/src/lib/sys.sh"

ui_title "eMerger uninstall"

removed_any=0
for rc in "$HOME/.bashrc" "${ZDOTDIR:-$HOME}/.zshrc" "$HOME/.config/fish/config.fish"; do
    [[ -f $rc ]] || continue
    if grep -q "emerger.sh" "$rc"; then
        sed -i.bak '/emerger\.sh/d;/# eMerger/d' "$rc"
        rm -f "$rc.bak"
        ui_ok "Cleaned $rc"
        removed_any=1
    fi
done
(( removed_any )) || ui_muted "No shell rc entries found."

if sys_has crontab && crontab -l 2>/dev/null | grep -q "emerger.sh"; then
    crontab -l 2>/dev/null | grep -v "emerger.sh" | crontab -
    ui_ok "Removed cronjob"
fi

if sys_has systemctl && systemctl --user list-unit-files 2>/dev/null | grep -q emerger; then
    systemctl --user disable --now emerger.timer 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/emerger.service" "$HOME/.config/systemd/user/emerger.timer"
    systemctl --user daemon-reload 2>/dev/null || true
    ui_ok "Removed systemd user timer"
fi

ui_muted "State and config kept at:"
ui_muted "  ${XDG_CONFIG_HOME:-$HOME/.config}/emerger/"
ui_muted "  ${XDG_STATE_HOME:-$HOME/.local/state}/emerger/"
ui_muted "Remove manually if you want them gone."

ui_ok "Uninstall complete. Repo still at $REPO_DIR."
