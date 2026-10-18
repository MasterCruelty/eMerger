#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# Installers take no flags: the environment never reaches ui_* arithmetic.
# Both read by the ui functions.
# shellcheck disable=SC2034
QUIET_LEVEL=0
# shellcheck disable=SC2034
UI_VERBOSE=0

# shellcheck source=src/lib/load.sh
source "$REPO_DIR/src/lib/load.sh" ui sys autoupdate

ui_title "eMerger uninstall"

# Drop the lines install.sh wrote to an rc file: the "# eMerger" header with the
# alias after it, and any other `up` alias pointing at emerger.sh. The user's
# own lines, comments mentioning eMerger included, stay.
_strip_rc() {
    local rc="$1" tmp
    tmp=$(mktemp "$rc.XXXXXX")
    awk '
        /^alias up[ =].*emerger\.sh/ { held = ""; next }
        held != "" { print held; held = "" }
        /^# eMerger( \(|$)/ { held = $0; next }
        { print }
        END { if (held != "") print held }
    ' "$rc" >"$tmp" && cat "$tmp" >"$rc"
    rm -f "$tmp"
}

has_removed=0
for rc in "$HOME/.bashrc" "${ZDOTDIR:-$HOME}/.zshrc" "$HOME/.config/fish/config.fish" "$(sys_shell_rc)"; do
    [[ -f $rc ]] || continue
    if grep -q "emerger.sh" "$rc"; then
        _strip_rc "$rc"
        ui_ok "Cleaned $rc"
        has_removed=1
    fi
done
(( has_removed )) || ui_muted "No shell rc entries found."

# Remove the completion files install.sh installed, recognised by their header.
bash_comp="${BASH_COMPLETION_USER_DIR:-$HOME/.local/share/bash-completion/completions}"
zsh_comp="$HOME/.zsh/completions"
fish_comp="$HOME/.config/fish/completions"
if brew_prefix=$(sys_brew_prefix); then
    [[ -d "$brew_prefix/etc/bash_completion.d" ]] && bash_comp="$brew_prefix/etc/bash_completion.d"
    [[ -d "$brew_prefix/share/zsh/site-functions" ]] && zsh_comp="$brew_prefix/share/zsh/site-functions"
fi
for comp in "$bash_comp/up" "$zsh_comp/_up" "$fish_comp/up.fish"; do
    if [[ -f $comp ]] && grep -q "completion for eMerger" "$comp"; then
        rm -f "$comp"
        ui_ok "Removed completion: $comp"
    fi
done

# Remove the man page install.sh installed, recognised by its title line.
man_page="${XDG_DATA_HOME:-$HOME/.local/share}/man/man1/up.1"
if [[ -f $man_page ]] && grep -q '^\.TH UP 1 .*eMerger' "$man_page"; then
    rm -f "$man_page"
    ui_ok "Removed man page: $man_page"
fi

if sys_has crontab && crontab -l 2>/dev/null | grep -q -E '^0 10 \* \* 0 bash ".*/src/emerger\.sh" -y -q -nl -ni$'; then
    if others=$(autoupdate_crontab_others); then
        { [[ -z $others ]] || printf '%s\n' "$others"; } | crontab -
        ui_ok "Removed cronjob"
    fi
fi

if sys_has systemctl && systemctl --user list-unit-files 2>/dev/null | grep -q emerger; then
    systemctl --user disable --now emerger.timer 2>/dev/null || true
    rm -f "$HOME/.config/systemd/user/emerger.service" "$HOME/.config/systemd/user/emerger.timer"
    systemctl --user daemon-reload 2>/dev/null || true
    ui_ok "Removed systemd user timer"
fi

# Settings, history and cache go only on an explicit yes: no terminal or no
# answer keeps them.
config_dir="${XDG_CONFIG_HOME:-$HOME/.config}/emerger"
state_dir="${XDG_STATE_HOME:-$HOME/.local/state}/emerger"
cache_dir="${XDG_CACHE_HOME:-$HOME/.cache}/emerger"
if ui_confirm "Delete your settings, history and cache too?" n; then
    rm -rf -- "$config_dir" "$state_dir" "$cache_dir"
    ui_ok "Removed settings, history and cache"
else
    ui_muted "Settings, history and cache kept at:"
    ui_muted "  $config_dir/"
    ui_muted "  $state_dir/"
    ui_muted "  $cache_dir/"
    ui_muted "Remove manually if you want them gone."
fi

ui_ok "Uninstall complete. Repo still at $REPO_DIR."
