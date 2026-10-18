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

ui_title "eMerger install"
install_path_check "$REPO_DIR" || exit 1

ALIAS_CMD="bash \"$REPO_DIR/src/emerger.sh\""

# Append the `up` alias to bash or zsh start-up file $1, created when
# missing. A file already naming emerger.sh is left alone.
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

# Append the `up` alias to fish's config.fish, created when missing. A file
# already naming emerger.sh is left alone.
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

# Stop rather than silently shadow another command or alias named `up`.
_check_no_other_up() {
    local rc other
    other=$(type -P up || true)
    if [[ -n $other ]]; then
        ui_err "A command named 'up' already exists: $other"
        ui_info "eMerger did not add its alias. Remove or rename the other 'up' and run install.sh again."
        exit 1
    fi
    # Definition lines of `up` in the files a shell reads at start, eMerger's own excepted.
    local defs='^[[:space:]]*(alias[[:space:]]+up([=[:space:]]|$)|function[[:space:]]+up([[:space:];({]|$)|up[[:space:]]*\(\))'
    for rc in "$HOME/.bashrc" "$HOME/.bash_aliases" "$HOME/.bash_profile" "$HOME/.profile" \
              "${ZDOTDIR:-$HOME}/.zshrc" "$HOME/.config/fish/config.fish" "$HOME/.config/fish/functions/up.fish"; do
        [[ -f $rc ]] || continue
        if grep -E "$defs" "$rc" | grep -qv "emerger.sh"; then
            ui_err "An alias or function named 'up' already exists in $rc"
            ui_info "eMerger did not add its alias. Remove or rename the other 'up' and run install.sh again."
            exit 1
        fi
    done
}
_check_no_other_up

has_installed=0
# macOS default shell is zsh (since Catalina): its rc file comes first.
if sys_is_macos; then
    _add_alias_bashzsh "${ZDOTDIR:-$HOME}/.zshrc"; has_installed=1
    [[ -f "$HOME/.bashrc" ]] && { _add_alias_bashzsh "$HOME/.bashrc"; }
elif [[ -f "$HOME/.bashrc" ]] || [[ $(basename "${SHELL:-}") == bash ]]; then
    _add_alias_bashzsh "$HOME/.bashrc"; has_installed=1
fi
if [[ -f "$HOME/.zshrc" ]] || [[ $(basename "${SHELL:-}") == zsh ]]; then
    _add_alias_bashzsh "${ZDOTDIR:-$HOME}/.zshrc"; has_installed=1
fi
if [[ -f "$HOME/.config/fish/config.fish" ]] || [[ $(basename "${SHELL:-}") == fish ]]; then
    _add_alias_fish; has_installed=1
fi
if (( ! has_installed )); then
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

# Man page where man looks for the user's own pages: `man up` after install.
man_dir="${XDG_DATA_HOME:-$HOME/.local/share}/man/man1"
if [[ -f "$REPO_DIR/man/up.1" ]]; then
    mkdir -p "$man_dir"
    install -m 0644 "$REPO_DIR/man/up.1" "$man_dir/up.1"
    ui_ok "Installed man page: $man_dir/up.1"
    if command -v manpath >/dev/null 2>&1 && ! manpath 2>/dev/null | tr ':' '\n' | grep -qx "${man_dir%/man1}"; then
        ui_muted "If 'man up' finds nothing, add ${man_dir%/man1} to MANPATH."
    fi
fi

# Default config skeleton.
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/emerger"
mkdir -p "$CONFIG_DIR/hooks/pre.d" "$CONFIG_DIR/hooks/post.d" "$CONFIG_DIR/profiles.d"
if [[ ! -f "$CONFIG_DIR/config.sh" ]]; then
    cat >"$CONFIG_DIR/config.sh" <<'EOF'
# eMerger user config. Sourced before argument parsing.
# Uncomment to change defaults.

# ARG_DEV=1           # always include dev toolchains
# ARG_WEATHER=1       # always show weather
# ARG_KEEP_TRASH=1    # never touch trash
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
