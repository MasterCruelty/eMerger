#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
}

teardown() {
    teardown_env
}

@test "resume: a manager that failed in the last run is not skipped" {
    plugin pa '[ ! -e "$HOME/fail-pa" ]'
    plugin pb '[ ! -e "$HOME/fail-pb" ]'
    touch "$HOME/fail-pa"
    run $EMERGER -y -nl -nc -nt --only pa,pb
    [ "$status" -eq 3 ]
    rm "$HOME/fail-pa"; touch "$HOME/fail-pb"
    run $EMERGER -y -nl -nc -nt --only pa,pb
    [ "$status" -eq 3 ]
    rm "$HOME/fail-pb" "$HOME/ran"
    run $EMERGER -y -nl -nc -nt --only pa,pb --resume
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/ran")" = "pb" ]
}
