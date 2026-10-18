#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    setup_minbin
}

teardown() {
    teardown_env
}

# Run pkg_run for $1 in dry-run with the flags in $2 (shell assignments).
pkg_dry() {
    sys_lib "DRY_RUN=1; ARG_SECURITY=0; ARG_DOWNLOAD_ONLY=0; ARG_DEV=0; ARG_ACCEPT_LICENSES=0; ARG_FIRMWARE=0
             ${2:-:}; pkg_run $1; echo rc=\$?"
}

# Run a snippet with the package dispatcher sourced, in dry-run.
pkg() {
    lib 'EMERGER_CONFIG=$HOME/.config/emerger
         source "$LIB/load.sh" estimate ignore registry detect icon recipes
         DRY_RUN=1; ARG_SECURITY=0; ARG_DOWNLOAD_ONLY=0; ARG_DEV=0
         '"$1"
}

@test "--download-only: a manager without a download mode is skipped, not recorded" {
    plugin pa ''
    run $EMERGER -y -nl -nc -nt --download-only --only pa
    [ "$status" -eq 0 ]
    [[ "$output" == *"skip pa (no download-only mode)"* ]]
    [ ! -e "$HOME/ran" ]
    [[ "$(tail -n 1 "$EMERGER_STATE/history.jsonl")" != *'"pa"'* ]]
    [ ! -e "$EMERGER_STATE/resume" ]
}

@test "sudo check: --download-only leaves managers without a download mode out" {
    stub snap 'exit 0'
    run lib 'ARG_DOWNLOAD_ONLY=1; ARG_ONLY=snap
             if run_needs_sudo; then echo sudo; else echo none; fi'
    [ "$output" = "none" ]
}

@test "download-only: managers without a download mode are skipped, never run" {
    local m
    for m in yay paru flatpak snap brew yum emerge npm; do
        run pkg_dry "$m" 'ARG_DOWNLOAD_ONLY=1'
        [ "$status" -eq 0 ]
        [[ "$output" == *"skip $m: no download-only mode"* ]]
        [[ "$output" != *"[dry-run]"* ]]
        [[ "$output" == *"rc=0" ]]
    done
}

@test "download-only: pacman, apt, dnf, zypper only download" {
    stub pacman 'exit 0'
    run pkg_dry pacman 'ARG_DOWNLOAD_ONLY=1'
    [[ "$output" == *"pacman -Syuw --noconfirm"* ]]
    [[ "$output" != *"-Syu --noconfirm"* ]]
    run pkg_dry dnf 'ARG_DOWNLOAD_ONLY=1'
    [[ "$output" == *"dnf upgrade -y --downloadonly"* ]]
    [[ "$output" != *"autoremove"* ]]
    run pkg_dry zypper 'ARG_DOWNLOAD_ONLY=1'
    [[ "$output" == *"zypper --non-interactive update --download-only"* ]]
    [[ "$output" != *"zypper clean"* ]]
    stub apt 'exit 0'
    run pkg_dry apt 'ARG_DOWNLOAD_ONLY=1'
    [[ "$output" == *"apt -o APT::Status-Fd=1 full-upgrade -y --download-only"* ]]
    [[ "$output" != *"autoremove"* ]]
}

@test "download-only off: yay still upgrades" {
    run pkg_dry yay ''
    [[ "$output" == *"[dry-run] yay -Syu --noconfirm"* ]]
}

@test "download-only: apt fix-broken only downloads, never installs" {
    stub apt 'exit 0'
    run pkg_dry apt 'ARG_DOWNLOAD_ONLY=1'
    [ "$status" -eq 0 ]
    [[ "$output" == *"apt -o APT::Status-Fd=1 --fix-broken install -y --download-only"* ]]
    run pkg_dry apt ''
    [[ "$output" == *"apt -o APT::Status-Fd=1 --fix-broken install -y"* ]]
    [[ "$output" != *"--fix-broken install -y --download-only"* ]]
}

@test "download-only: softwareupdate with --security downloads only the recommended updates" {
    run pkg_dry softwareupdate 'ARG_DOWNLOAD_ONLY=1; ARG_SECURITY=1'
    [ "$status" -eq 0 ]
    [[ "$output" == *"softwareupdate --download --recommended"* ]]
    [[ "$output" != *"--all"* ]]
    run pkg_dry softwareupdate 'ARG_DOWNLOAD_ONLY=1'
    [[ "$output" == *"softwareupdate --download --all"* ]]
}

@test "softwareupdate downloads without installing under --download-only" {
    run pkg 'ARG_DOWNLOAD_ONLY=1; ARG_ACCEPT_LICENSES=0; pkg_run softwareupdate'
    [ "$status" -eq 0 ]
    [[ "$output" == *"softwareupdate --download --all"* ]]
    [[ "$output" != *"--install"* ]]
    [[ "$output" != *"skip softwareupdate"* ]]
}
