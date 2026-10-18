#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
}

teardown() {
    teardown_env
}

@test "args: repeated --profile loads the last one only" {
    mkdir -p "$XDG_CONFIG_HOME/emerger/profiles.d"
    echo 'touch "$HOME/prof-a"' >"$XDG_CONFIG_HOME/emerger/profiles.d/a.sh"
    echo 'touch "$HOME/prof-b"' >"$XDG_CONFIG_HOME/emerger/profiles.d/b.sh"
    run $EMERGER -n -y -nl --only none --profile a --profile=b
    [ "$status" -eq 0 ]
    [ -e "$HOME/prof-b" ]
    [ ! -e "$HOME/prof-a" ]
}

@test "profiles: safe and work add to ARG_EXCEPT from config.sh" {
    run bash -c "ARG_EXCEPT=npm; source '$REPO_DIR/share/profiles/safe.sh'; echo \$ARG_EXCEPT"
    [ "$output" = "npm,flatpak,snap" ]
    run bash -c "ARG_EXCEPT=npm; source '$REPO_DIR/share/profiles/work.sh'; echo \$ARG_EXCEPT"
    [ "$output" = "npm,yay,paru" ]
    run bash -c "set -u; source '$REPO_DIR/share/profiles/safe.sh'; echo \$ARG_EXCEPT"
    [ "$output" = "flatpak,snap" ]
}

@test "safe and work profiles skip the right managers" {
    run bash -c "source '$REPO_DIR/share/profiles/safe.sh'; echo \$ARG_EXCEPT"
    [ "$output" = "flatpak,snap" ]
    run bash -c "source '$REPO_DIR/share/profiles/work.sh'; echo \$ARG_EXCEPT \$ARG_NO_FIRMWARE"
    [ "$output" = "yay,paru 1" ]
}

@test "profiles: --list-profiles prints the shipped descriptions in English" {
    run $EMERGER --list-profiles
    [ "$status" -eq 0 ]
    [[ "$output" == *"home"*"everything: dev toolchains, firmware, parallel mode and the weather line"* ]]
    [[ "$output" == *"work"*"security only, unattended, no firmware, skips yay and paru"* ]]
    [[ "$output" == *"server"*"headless: quiet, security only, no prompts, no firmware"* ]]
    [[ "$output" == *"safe"*"least change: security only, no firmware, skips flatpak and snap"* ]]
}

@test "profiles: the .ps1 descriptions are English and keep their line ending" {
    run grep -h '^# description:' "$REPO_DIR"/share/profiles/*.ps1
    [ "$status" -eq 0 ]
    [[ "$output" != *" niente "* && "$output" != *" solo "* && "$output" != *"lavoro"* && "$output" != *"nessun"* && "$output" != *"casa"* ]]
    [ "$(grep -c $'\r$' "$REPO_DIR/share/profiles/home.ps1")" -gt 0 ]
}

@test "profiles: a user profile whose last command fails still runs the update" {
    plugin pa ''
    mkdir -p "$XDG_CONFIG_HOME/emerger/profiles.d"
    echo '[[ -f /nonexistent ]] && ARG_YES=1' >"$XDG_CONFIG_HOME/emerger/profiles.d/q.sh"
    run $EMERGER -y -nl -nc -nt --only pa --profile q
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/ran")" = "pa" ]
}
