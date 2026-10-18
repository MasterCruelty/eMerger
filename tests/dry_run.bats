#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    # Managers the tests rely on, so detection does not depend on the host.
    for m in apt snap; do printf '#!/bin/sh\nexit 0\n' >"$STUBS/$m"; chmod +x "$STUBS/$m"; done
    printf '#!/bin/sh\necho "sudo $*" >>"$HOME/sudo.log"\n' >"$STUBS/sudo"; chmod +x "$STUBS/sudo"
}

teardown() {
    teardown_env
}

@test "dry-run completes without sudo" {
    run $EMERGER -n -y -nl -ni -nc -nt -q
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/sudo.log" ]
}

@test "dry-run: no ibus restart, package diff and history untouched" {
    stub pgrep 'exit 0'
    mkdir -p "$EMERGER_STATE"
    echo keep >"$EMERGER_STATE/pkgs.diff"
    run $EMERGER -n -y -nl --only none
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/ibus.log" ]
    [ "$(cat "$EMERGER_STATE/pkgs.diff")" = "keep" ]
    [ ! -e "$EMERGER_STATE/history.jsonl" ]
}

@test "real run: ibus is restarted when its daemon runs" {
    stub pgrep 'exit 0'
    run $EMERGER -y -nl -nc -nt --only none
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/ibus.log")" = "ibus restart" ]
}

@test "dry-run --reboot with a reboot pending: attack sudo reboot, expected only a message" {
    stub needs-restarting 'exit 1'
    stub sudo 'echo "$@" >"$HOME/sudo-called"'
    run env PATH="$STUBS:$PATH" $EMERGER -n --reboot
    [ "$status" -eq 0 ]
    [[ "$output" == *"would reboot"* ]]
    [ ! -e "$HOME/sudo-called" ]
}

@test "dry-run -au: attack unit files and timer enabled, expected nothing written" {
    stub systemctl 'echo "$@" >>"$HOME/systemctl-called"'
    stub crontab 'echo "$@" >>"$HOME/crontab-called"'
    run env PATH="$STUBS:$PATH" $EMERGER -n -au
    [ "$status" -eq 0 ]
    [[ "$output" == *"[dry-run]"* ]]
    ! grep -q enable "$HOME/systemctl-called" 2>/dev/null || false
    ! grep -q daemon-reload "$HOME/systemctl-called" 2>/dev/null || false
    [ ! -e "$HOME/crontab-called" ]
    [ ! -e "$HOME/.config/systemd/user/emerger.service" ]
}

@test "dry-run -rc: attack detection cache deleted, expected cache kept" {
    mkdir -p "$XDG_CACHE_HOME/emerger"; echo apt >"$XDG_CACHE_HOME/emerger/detected"
    run $EMERGER -n -rc -y -nl -nc -nt --only none
    [ "$status" -eq 0 ]
    [[ "$output" == *"[dry-run]"* ]]
    [ -f "$XDG_CACHE_HOME/emerger/detected" ]
}

@test "real run: attack the ibus restart inheriting the lock fd, expected fd 9 closed" {
    [ -e /proc/self/fd ] || skip "no /proc"
    command -v flock >/dev/null || skip "flock not available"
    stub pgrep 'exit 0'
    stub ibus 'if [ -e /proc/self/fd/9 ]; then echo 1; else echo 0; fi >"$HOME/ibus.fd"'
    run $EMERGER -y -nl -nc -nt --only none
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/ibus.fd")" = "0" ]
}
