#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    setup_minbin
}

teardown() {
    teardown_env
}

@test "sudo keepalive: does not hold stdout open after the run" {
    stub sudo 'exit 0'
    SECONDS=0
    run timeout 20 bash -c "lib_out=\$(bash -c 'source \"$LIB/load.sh\" ui log sys run; run_sudo_keepalive; echo started'); echo \"\$lib_out\""
    [ "$status" -eq 0 ]
    [ "$output" = "started" ]
    [ "$SECONDS" -lt 10 ]
}

@test "sudo keepalive: TERM stops its sleep too" {
    stub sudo 'exit 0'
    # Follow this keepalive's own sleep by PID: other runs on the machine may sleep too.
    run lib 'run_sudo_keepalive 737; sleep 0.5
             child=$(pgrep -P "$SUDO_KEEPALIVE_PID" -x sleep)
             kill -TERM "$SUDO_KEEPALIVE_PID"; sleep 0.5
             [[ -n $child ]] && ! kill -0 "$child" 2>/dev/null && echo stopped'
    [ "$output" = "stopped" ]
}

@test "sudo keepalive: exits once its parent is killed" {
    stub sudo 'exit 0'
    bash -c 'source "$LIB/load.sh" ui log sys run
             run_sudo_keepalive 1; echo "$SUDO_KEEPALIVE_PID" >"$HOME/k.pid"; sleep 30' >/dev/null 2>&1 &
    local parent=$!
    sleep 1
    kill -9 "$parent"
    sleep 3
    local k; k=$(cat "$HOME/k.pid")
    run kill -0 "$k"
    kill "$k" 2>/dev/null || true
    [ "$status" -ne 0 ]
}

@test "sudo check: --no-firmware leaves fwupd out" {
    stub fwupdmgr 'exit 0'
    run lib 'ARG_FIRMWARE=1; ARG_NO_FIRMWARE=1; ARG_ONLY=fwupd
             if run_needs_sudo; then echo sudo; else echo none; fi'
    [ "$output" = "none" ]
}

@test "sudo check: --resume leaves completed managers out" {
    stub apt 'exit 0'
    run lib 'ARG_RESUME=1; ARG_ONLY=apt; RESUME_DONE=(apt)
             if run_needs_sudo; then echo sudo; else echo none; fi'
    [ "$output" = "none" ]
    run lib 'ARG_ONLY=apt; RESUME_DONE=()
             if run_needs_sudo; then echo sudo; else echo none; fi'
    [ "$output" = "sudo" ]
}

@test "pkg_run: sudo prefix only when not root" {
    stub apt 'exit 0'
    run lib 'DRY_RUN=1; PATH=$STUBS:/usr/bin:/bin; sys_is_root() { return 0; }; pkg_run apt 2>&1'
    [[ "$output" == *"[dry-run] apt"* ]]
    [[ "$output" != *"sudo"* ]]
    run lib 'DRY_RUN=1; PATH=$STUBS:/usr/bin:/bin; sys_is_root() { return 1; }; pkg_run apt 2>&1'
    [[ "$output" == *"[dry-run] sudo apt"* ]]
}

@test "privilege prefix: empty as root, sudo otherwise" {
    run sys_lib 'sys_is_root() { return 0; }; echo "root=[$(sys_sudo_prefix)]"
                 sys_is_root() { return 1; }; echo "user=[$(sys_sudo_prefix)]"'
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "root=[]" ]
    [ "${lines[1]}" = "user=[sudo]" ]
}
