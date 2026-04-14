#!/usr/bin/env bash
# System detection helpers.

sys_has() { command -v "$1" >/dev/null 2>&1; }
sys_is_macos() { [[ $(uname -s) == Darwin ]]; }
sys_is_linux() { [[ $(uname -s) == Linux ]]; }
sys_brew_prefix() { command -v brew >/dev/null 2>&1 && brew --prefix 2>/dev/null; }

sys_os() {
    case "$(uname -s)" in
        Linux)   echo linux ;;
        Darwin)  echo macos ;;
        MINGW*|MSYS*|CYGWIN*) echo windows ;;
        *) echo unknown ;;
    esac
}

sys_distro() {
    if [[ -f /etc/os-release ]]; then
        # shellcheck disable=SC1091
        . /etc/os-release
        echo "${PRETTY_NAME:-${NAME:-unknown}}"
    else
        uname -sr
    fi
}

sys_shell_rc() {
    local sh
    sh=$(basename "${SHELL:-bash}")
    case "$sh" in
        bash) echo "$HOME/.bashrc" ;;
        zsh)  echo "${ZDOTDIR:-$HOME}/.zshrc" ;;
        fish) echo "$HOME/.config/fish/config.fish" ;;
        *)    echo "$HOME/.${sh}rc" ;;
    esac
}

sys_on_battery() {
    [[ -d /sys/class/power_supply ]] || return 1
    local ac found=0
    for ac in /sys/class/power_supply/A{C,DP,C0,DP0}*/online; do
        [[ -f $ac ]] || continue
        found=1
        [[ $(cat "$ac" 2>/dev/null) == 1 ]] && return 1
    done
    (( found )) && return 0
    return 1
}

sys_battery_percent() {
    local cap
    for cap in /sys/class/power_supply/BAT*/capacity; do
        [[ -f $cap ]] && { cat "$cap"; return; }
    done
    echo 100
}

sys_is_root() { [[ ${EUID:-$(id -u)} -eq 0 ]]; }
