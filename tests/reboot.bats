#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    setup_minbin
}

teardown() {
    teardown_env
}

@test "reboot_check: Arch without the linux package returns 0, no reboot" {
    stub pacman '[ "$1" = "-Q" ] && exit 1; exit 0'
    stub dpkg-query 'exit 1'
    run sys_lib 'REBOOT_REQUIRED_FILE=$HOME/none; reboot_check; echo "rc=$? need=$REBOOT_IS_NEEDED"'
    [ "$status" -eq 0 ]
    [ "$output" = "rc=0 need=0" ]
}

@test "reboot_check: dnf needs-restarting exit 1 means reboot, other failures unknown" {
    stub dnf 'exit 1'
    run sys_lib 'REBOOT_REQUIRED_FILE=$HOME/none; reboot_check; echo "need=$REBOOT_IS_NEEDED $REBOOT_REASON"'
    [ "$output" = "need=1 dnf needs-restarting" ]
    stub dnf 'echo "Unknown argument" >&2; exit 2'
    run sys_lib 'REBOOT_REQUIRED_FILE=$HOME/none; reboot_check; echo "need=$REBOOT_IS_NEEDED"'
    [ "$status" -eq 0 ]
    [ "$output" = "need=0" ]
    stub needs-restarting 'exit 3'
    run sys_lib 'REBOOT_REQUIRED_FILE=$HOME/none; reboot_check; echo "need=$REBOOT_IS_NEEDED"'
    [ "$output" = "need=0" ]
}

@test "reboot_check: flag file counts its packages" {
    touch "$HOME/rr"; printf 'linux\nlibc6\n' >"$HOME/rr.pkgs"
    run sys_lib 'REBOOT_REQUIRED_FILE=$HOME/rr; reboot_check; echo "need=$REBOOT_IS_NEEDED $REBOOT_REASON"'
    [ "$output" = "need=1 $HOME/rr exists (2 pkg(s))" ]
}

@test "reboot_now: root runs reboot itself, a user goes through sudo, dry-run only prints" {
    stub reboot 'echo "reboot $*" >>"$HOME/calls"'
    run sys_lib 'DRY_RUN=0; sys_is_root() { return 0; }; reboot_now; echo after'
    [[ "$output" != *after* ]]
    [ "$(cat "$HOME/calls")" = "reboot " ]
    stub sudo 'echo "sudo $*" >>"$HOME/calls"; exec "$@"'
    rm "$HOME/calls"
    run sys_lib 'DRY_RUN=0; sys_is_root() { return 1; }; reboot_now'
    [ "$(head -n 1 "$HOME/calls")" = "sudo reboot" ]
    rm "$HOME/calls"
    run sys_lib 'DRY_RUN=1; REBOOT_REASON=why; sys_is_root() { return 0; }; reboot_now; echo "rc=$?"'
    [[ "$output" == *"would reboot: reboot (why)"* ]]
    [[ "$output" == *"rc=0"* ]]
    run sys_lib 'DRY_RUN=1; REBOOT_REASON=why; sys_is_root() { return 1; }; reboot_now'
    [[ "$output" == *"would reboot: sudo reboot (why)"* ]]
    [ ! -e "$HOME/calls" ]
}

@test "reboot advisory: names reboot without sudo as root" {
    run sys_lib 'REBOOT_IS_NEEDED=1; REBOOT_REASON=x; sys_is_root() { return 0; }; reboot_advisory'
    [[ "$output" == *"run reboot  or up --reboot"* ]]
    run sys_lib 'REBOOT_IS_NEEDED=1; REBOOT_REASON=x; sys_is_root() { return 1; }; reboot_advisory'
    [[ "$output" == *"run sudo reboot  or up --reboot"* ]]
}
