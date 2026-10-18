#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    setup_minbin
}

teardown() {
    teardown_env
}

@test "notify: macOS posts through osascript" {
    stub uname 'echo Darwin'
    stub osascript 'echo "$*" >>"$HOME/osa.calls"'
    run sys_lib 'unset DISPLAY WAYLAND_DISPLAY; SUMMARY_ERRORS=0; SUMMARY_MANAGERS=(apt brew); notify_send_result; echo rc=$?'
    [ "$status" -eq 0 ]
    [ "$output" = "rc=0" ]
    grep -q '2 manager(s) updated' "$HOME/osa.calls"
}

@test "notify: Linux without a display sends nothing" {
    stub notify-send 'echo "$*" >>"$HOME/ns.calls"'
    run sys_lib 'unset DISPLAY WAYLAND_DISPLAY; SUMMARY_ERRORS=1; SUMMARY_MANAGERS=(); notify_send_result; echo rc=$?'
    [ "$output" = "rc=0" ]
    [ ! -e "$HOME/ns.calls" ]
    run sys_lib 'DISPLAY=:9; SUMMARY_ERRORS=1; SUMMARY_MANAGERS=(); notify_send_result'
    grep -q 'Finished with 1 error' "$HOME/ns.calls"
}
