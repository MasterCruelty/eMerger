#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
}

teardown() {
    teardown_env
}

@test "summary: -qqq --reboot-exit with a reboot pending exits 4" {
    stub needs-restarting 'exit 1'
    run $EMERGER -n -y -qqq --reboot-exit --only none
    [ "$status" -eq 4 ]
    [[ "$output" != *"Reboot recommended"* ]]
}

@test "summary: -qq history line records the pending reboot" {
    stub needs-restarting 'exit 1'
    run $EMERGER -y -qq -nl -nc -nt --only none
    [ "$status" -eq 0 ]
    [[ "$(tail -n 1 "$EMERGER_STATE/history.jsonl")" == *'"reboot":1'* ]]
}

@test "summary: -qqq still appends the history line" {
    run $EMERGER -y -qqq -nl -nc -nt --only none
    [ "$status" -eq 0 ]
    [ "$(wc -l <"$EMERGER_STATE/history.jsonl")" -eq 1 ]
}
