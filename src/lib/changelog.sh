#!/usr/bin/env bash
# Fetch recent changelog for a package using the installed manager.

changelog_show() {
    local pkg="$1"
    if [[ -z $pkg ]]; then
        ui_err "usage: up --changelog <package>"
        return 2
    fi
    ui_title "Changelog: $pkg"
    if sys_has apt && apt changelog "$pkg" 2>/dev/null | head -n 60 | grep -q .; then
        apt changelog "$pkg" 2>/dev/null | head -n 60
        return 0
    fi
    if sys_has dnf; then
        if dnf changelog "$pkg" 2>/dev/null | grep -q .; then
            dnf changelog "$pkg" 2>/dev/null | head -n 60
            return 0
        fi
        if dnf updateinfo info "$pkg" 2>/dev/null | grep -q .; then
            dnf updateinfo info "$pkg" 2>/dev/null | head -n 60
            return 0
        fi
    fi
    if sys_has pacman; then
        pacman -Qi "$pkg" 2>/dev/null || pacman -Si "$pkg" 2>/dev/null
        ui_muted "(pacman has no native changelog; see https://archlinux.org/packages/)"
        return 0
    fi
    if sys_has brew; then
        brew log --oneline -n 20 "$pkg" 2>/dev/null || brew info "$pkg"
        return 0
    fi
    ui_err "No supported package manager with changelog info found."
    return 1
}
