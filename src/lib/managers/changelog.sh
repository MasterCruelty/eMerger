#!/usr/bin/env bash
# Fetch recent changelog for a package using the installed manager.

# Print, stripped of terminal control sequences, the first 60 lines of package
# $1's changelog from the first manager that has one (apt, dnf changelog, dnf
# updateinfo), else pacman's package info or brew's log. Return 2 without a name, 1 when nothing answers.
changelog_show() {
    local package="$1" output
    if [[ -z $package ]]; then
        ui_err "usage: up --changelog <package>"
        return 2
    fi
    ui_title "Changelog: $package"
    # Capture once: under pipefail, `head` closing the pipe early fails the
    # producer with SIGPIPE, so its status says nothing about the output.
    if sys_has apt; then
        output=$({ apt changelog "$package" 2>/dev/null || true; } | head -n 60)
        if [[ -n $output ]]; then printf '%s\n' "$output" | run_sanitize; return 0; fi
    fi
    if sys_has dnf; then
        output=$({ dnf changelog "$package" 2>/dev/null || true; } | head -n 60)
        if [[ -n $output ]]; then printf '%s\n' "$output" | run_sanitize; return 0; fi
        output=$({ dnf updateinfo info "$package" 2>/dev/null || true; } | head -n 60)
        if [[ -n $output ]]; then printf '%s\n' "$output" | run_sanitize; return 0; fi
    fi
    if sys_has pacman; then
        ui_muted "package info (pacman has no changelog), changes at https://archlinux.org/packages/"
        { pacman -Qi "$package" 2>/dev/null || pacman -Si "$package" 2>/dev/null || true; } | run_sanitize
        return 0
    fi
    if sys_has brew; then
        { brew log --oneline -n 20 "$package" 2>/dev/null || brew info "$package"; } | run_sanitize
        return 0
    fi
    ui_err "No supported package manager with changelog info found."
    return 1
}
