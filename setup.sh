#!/usr/bin/env bash
set -Eeuo pipefail

REPO_DIR=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)

# shellcheck source=src/lib/ui.sh
source "$REPO_DIR/src/lib/ui.sh"
# shellcheck source=src/lib/sys.sh
source "$REPO_DIR/src/lib/sys.sh"

ui_title "eMerger setup"

ALIAS_CMD="bash \"$REPO_DIR/src/emerger.sh\""

_add_alias_bashzsh() {
    local rc="$1"
    touch "$rc"
    if grep -q "emerger.sh" "$rc"; then
        ui_ok "Alias already present in $rc"
        return
    fi
    {
        printf '\n# eMerger (https://github.com/MasterCruelty/eMerger)\n'
        printf "alias up='%s'\n" "$ALIAS_CMD"
    } >>"$rc"
    ui_ok "Added 'up' alias to $rc"
}

_add_alias_fish() {
    local conf="$HOME/.config/fish/config.fish"
    mkdir -p "$(dirname "$conf")"
    touch "$conf"
    if grep -q "emerger.sh" "$conf"; then
        ui_ok "Alias already present in $conf"
        return
    fi
    {
        printf '\n# eMerger\n'
        printf "alias up '%s'\n" "$ALIAS_CMD"
    } >>"$conf"
    ui_ok "Added 'up' alias to $conf"
}

installed_any=0
# macOS default shell is zsh (since Catalina); prioritize accordingly.
if sys_is_macos; then
    _add_alias_bashzsh "${ZDOTDIR:-$HOME}/.zshrc"; installed_any=1
    [[ -f "$HOME/.bashrc" ]] && { _add_alias_bashzsh "$HOME/.bashrc"; }
elif [[ -f "$HOME/.bashrc" ]] || [[ $(basename "${SHELL:-}") == bash ]]; then
    _add_alias_bashzsh "$HOME/.bashrc"; installed_any=1
fi
if [[ -f "$HOME/.zshrc" ]] || [[ $(basename "${SHELL:-}") == zsh ]]; then
    _add_alias_bashzsh "${ZDOTDIR:-$HOME}/.zshrc"; installed_any=1
fi
if [[ -f "$HOME/.config/fish/config.fish" ]] || [[ $(basename "${SHELL:-}") == fish ]]; then
    _add_alias_fish; installed_any=1
fi
if (( ! installed_any )); then
    _add_alias_bashzsh "$(sys_shell_rc)"
fi

chmod +x "$REPO_DIR/src/emerger.sh"

# Install shell completions if the user's dirs exist.
install_completion() {
    local src="$1" dest="$2"
    [[ -f $src ]] || return 0
    mkdir -p "$(dirname "$dest")"
    if [[ -e $dest ]] && ! diff -q "$src" "$dest" >/dev/null 2>&1; then
        cp -f "$dest" "$dest.backup-$(date +%s)"
    fi
    install -m 0644 "$src" "$dest"
    ui_ok "Installed completion: $dest"
}

bash_comp="${BASH_COMPLETION_USER_DIR:-$HOME/.local/share/bash-completion/completions}"
zsh_comp="$HOME/.zsh/completions"
fish_comp="$HOME/.config/fish/completions"
# On macOS with Homebrew, prefer brew's own completion dirs.
if brew_prefix=$(sys_brew_prefix); then
    [[ -d "$brew_prefix/etc/bash_completion.d" ]] && bash_comp="$brew_prefix/etc/bash_completion.d"
    [[ -d "$brew_prefix/share/zsh/site-functions" ]] && zsh_comp="$brew_prefix/share/zsh/site-functions"
fi

install_completion "$REPO_DIR/completions/up.bash" "$bash_comp/up"
install_completion "$REPO_DIR/completions/_up"     "$zsh_comp/_up"
install_completion "$REPO_DIR/completions/up.fish" "$fish_comp/up.fish"

# Default config skeleton.
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/emerger"
mkdir -p "$CONFIG_DIR/hooks/pre.d" "$CONFIG_DIR/hooks/post.d" "$CONFIG_DIR/profiles.d"
if [[ ! -f "$CONFIG_DIR/config.sh" ]]; then
    cat >"$CONFIG_DIR/config.sh" <<'EOF'
# eMerger user config. Sourced before argument parsing.
# Uncomment to change defaults.

# ARG_DEV=1           # always include dev toolchains
# ARG_WEATHER=1       # always show weather
# ARG_NO_TRASH=1      # never touch trash
# DISK_MIN_FREE_MB=2048
# QUIET_HOURS="23:00-07:00"    # skip when timer fires inside this window
EOF
    ui_ok "Created $CONFIG_DIR/config.sh"
fi
if [[ ! -f "$CONFIG_DIR/ignore.list" ]]; then
    cat >"$CONFIG_DIR/ignore.list" <<'EOF'
# eMerger ignore list: one package name per line. Comments with #.
# Note: pacman honors this natively via --ignore.
# For apt use: sudo apt-mark hold <pkg>
# For dnf use: sudo dnf versionlock add <pkg>
EOF
    ui_ok "Created $CONFIG_DIR/ignore.list"
fi

ui_info "Open a new shell (or 'source ~/.bashrc') and run: up --help"
