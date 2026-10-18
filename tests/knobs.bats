#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
}

teardown() {
    teardown_env
}

@test "safety switch: DRY_RUN=true in config.sh is refused with exit 2" {
    plugin pa ''
    echo 'DRY_RUN=true' >"$XDG_CONFIG_HOME/emerger/config.sh"
    run $EMERGER -y -nl -nc -nt --only pa
    [ "$status" -eq 2 ]
    [[ "$output" == *'DRY_RUN="true"'* ]]
    [ ! -e "$HOME/ran" ]
}

@test "safety switch: RPI_ABORT_ON_UNDERVOLTAGE=yes is refused with exit 2" {
    run env RPI_ABORT_ON_UNDERVOLTAGE=yes $EMERGER -n -y -nl --only none
    [ "$status" -eq 2 ]
    [[ "$output" == *'RPI_ABORT_ON_UNDERVOLTAGE="yes"'* ]]
}

@test "ARG_ASCII: attack arithmetic injection from the environment, expected ignored" {
    run env ARG_ASCII='BASH_VERSINFO[$(touch $HOME/pwned-emoji)]' $EMERGER -n -y -nl --only none
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/pwned-emoji" ]
}

@test "SUMMARY_FREED_KB: attack arithmetic injection from the environment, expected ignored" {
    run env SUMMARY_FREED_KB='BASH_VERSINFO[$(touch $HOME/pwned-freed)]' $EMERGER -n -y -nl --only none
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/pwned-freed" ]
}

@test "numeric knob: attack arithmetic injection from the environment, expected default" {
    run env DISK_MIN_FREE_MB='ARG_YES[$(touch $HOME/M)]' RETRY_ATTEMPTS='a[$(touch $HOME/N)]' \
        $EMERGER -n -y -nl -nc -nt --only none
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/M" ]
    [ ! -e "$HOME/N" ]
    [[ "$output" == *"DISK_MIN_FREE_MB"*"1024"* ]]
}

@test "numeric knob: 08 reads as 8, 1m falls back with a warning" {
    run lib 'EMERGER_PROMPT_TIMEOUT=08; knob_int EMERGER_PROMPT_TIMEOUT 60; echo "$EMERGER_PROMPT_TIMEOUT"
             EMERGER_PROMPT_TIMEOUT=1m; knob_int EMERGER_PROMPT_TIMEOUT 60 2>&1; echo "$EMERGER_PROMPT_TIMEOUT"'
    [ "${lines[0]}" = "8" ]
    [[ "${lines[1]}" == *"EMERGER_PROMPT_TIMEOUT"* ]]
    [ "${lines[2]}" = "60" ]
}
