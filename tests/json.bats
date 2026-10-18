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

@test "json mode emits a single json object on stdout" {
    run $EMERGER -n -y --json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"managers":'* ]]
    [[ "$output" == *'"errors":'* ]]
}

@test "summary: --json prints the line appended to history" {
    stub needs-restarting 'exit 1'
    run bash -c "$EMERGER --json -y -nc -nt --only none 2>/dev/null"
    [ "$status" -eq 0 ]
    [[ "$output" == *'"reboot":1'* ]]
    [ "$output" = "$(tail -n 1 "$EMERGER_STATE/history.jsonl")" ]
}

@test "--json: hook stdout stays off stdout" {
    mkdir -p "$XDG_CONFIG_HOME/emerger/hooks/pre.d"
    echo 'echo hook-says-hi' >"$XDG_CONFIG_HOME/emerger/hooks/pre.d/h.sh"
    run bash -c "$EMERGER --json -y -nc -nt --only none 2>/dev/null"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [[ "${lines[0]}" == \{*\} ]]
}

@test "--json -v: manager output stays off stdout" {
    plugin pa 'run_cmd step echo noisy-manager'
    run bash -c "$EMERGER --json -v -y -nc -nt --only pa 2>/dev/null"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [[ "${lines[0]}" == \{*\} ]]
}

@test "json: plugin stdout goes to stderr, stdout holds one JSON line" {
    mkdir -p "$XDG_CONFIG_HOME/emerger/managers.d"
    cat >"$XDG_CONFIG_HOME/emerger/managers.d/noisy.sh" <<'EOS'
PM_PLUGIN_SLUG=noisy
pm_noisy_detect() { return 0; }
pm_noisy_run() { echo "plugin chatter"; return 0; }
EOS
    chmod 600 "$XDG_CONFIG_HOME/emerger/managers.d/noisy.sh"
    run bash -c "$EMERGER --json -y --only noisy 2>/dev/null"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [[ "${lines[0]}" == \{*\"noisy\"*\} ]]
}

@test "--json prints only one JSON line on stdout" {
    run bash -c "$EMERGER --json -n -y --only none 2>/dev/null"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [[ "${lines[0]}" == \{*\} ]]
}
