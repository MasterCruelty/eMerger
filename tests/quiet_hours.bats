#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
}

teardown() {
    teardown_env
}

# Stub date so `date +%H%M` prints $1, every other call reaching the real date.
stub_clock() {
    local real
    real=$(PATH=${PATH#"$STUBS:"} command -v date)
    stub date "[ \"\$1\" = +%H%M ] && { echo $1; exit 0; }; exec $real \"\$@\""
}

@test "quiet hours: the clock comes from date, never from the environment" {
    stub_clock 0700
    run env QUIET_HOURS=08:00-18:00 EMERGER_NOW_HHMM=1200 $EMERGER -n -y -nl --only none
    [ "$status" -eq 0 ]
    [[ "$output" != *"quiet hours"* ]]
    [[ "$output" == *"No supported package managers"* ]]
}

@test "quiet hours: inside the window skips the run, at its end time the run goes on, across midnight too" {
    local window clock verdict
    while read -r window clock verdict; do
        stub_clock "$clock"
        run env QUIET_HOURS="$window" $EMERGER -n -y -nl --only none
        [ "$status" -eq 0 ]
        [[ "$output" != *"value too great"* ]]
        [[ "$output" != *"QUIET_HOURS="* ]]
        if [[ $verdict == skip ]]; then
            [[ "$output" == *"quiet hours, skipping"* ]]
            [[ "$output" != *"No supported package managers"* ]]
        else
            [[ "$output" != *"quiet hours"* ]]
            [[ "$output" == *"No supported package managers"* ]]
        fi
    done <<'ROWS'
08:00-18:00 1200 skip
22:00-07:00 0659 skip
22:00-07:00 0700 run
ROWS
}

@test "quiet hours: a malformed window warns and the run proceeds" {
    run env QUIET_HOURS=soon $EMERGER -n -y -nl --only none
    [ "$status" -eq 0 ]
    [[ "$output" == *'QUIET_HOURS="soon"'* ]]
    [[ "$output" == *"No supported package managers"* ]]
}
