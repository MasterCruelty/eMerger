#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
}

teardown() {
    teardown_env
}

@test "interrupt: TERM during a manager stops the run with exit 1" {
    plugin pa 'kill -TERM $$'
    plugin pb ''
    run $EMERGER -y -nl -nc -nt --only pa,pb
    [ "$status" -eq 1 ]
    [ "$(cat "$HOME/ran")" = "pa" ]
    [[ "$output" == *"Interrupted"* ]]
}

@test "interrupt: TERM inside a command removes its capture file and skips the rest" {
    stub killparent 'kill -TERM $PPID; sleep 1'
    plugin pa 'run_cmd step killparent'
    plugin pb ''
    run $EMERGER -y -nl -nc -nt --only pa,pb
    [ "$status" -eq 1 ]
    [ "$(cat "$HOME/ran")" = "pa" ]
    [ -z "$(ls "$TMPDIR")" ]
}

@test "interrupt: Ctrl-C at a prompt exits 1, never takes the default" {
    command -v script >/dev/null || skip "script not available"
    run bash -c "(sleep 2; printf '\003'; sleep 2) | script -qfec \"env DISK_MIN_FREE_MB=999999999 $EMERGER -nl -nc -nt --only none\" /dev/null"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Interrupted"* ]]
    [[ "$output" != *"using the default"* ]]
}

@test "interrupt: TERM during --parallel removes the parallel capture files" {
    plugin pp 'export MAINPID=$$; run_cmd step sh -c "kill -TERM \$MAINPID; sleep 5"' 'pm_pp_parallel() { return 0; }'
    run $EMERGER -y -nl -nc -nt --parallel --only pp
    [ "$status" -eq 1 ]
    sleep 1
    [ -z "$(ls "$TMPDIR")" ]
}

@test "interrupt: pkill, which stops the --parallel managers, is listed as optional in README and manual" {
    grep -q '`pkill`' "$REPO_DIR/README.md"
    grep -q 'texttt{pkill}' "$REPO_DIR/doc/documentation.tex"
}
