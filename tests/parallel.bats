#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
}

teardown() {
    teardown_env
}

@test "parallel: step counter reaches the total" {
    plugin sa ''
    plugin sb ''
    plugin pc '' 'pm_pc_parallel() { return 0; }'
    plugin pd '' 'pm_pd_parallel() { return 0; }'
    run $EMERGER -y -nl -nc -nt --parallel --only sa,sb,pc,pd
    [ "$status" -eq 0 ]
    [[ "$output" == *"1/3"* ]]
    [[ "$output" == *"3/3"* ]]
    [[ "$output" != *"/4"* ]]
}

@test "parallel: a transient failure is retried as in a serial run" {
    stub flaky 'if [ -e "$HOME/flaked" ]; then exit 0; fi; touch "$HOME/flaked"; echo "Temporary failure resolving host"; exit 1'
    plugin pp 'run_cmd step flaky' 'pm_pp_parallel() { return 0; }'
    run env RETRY_DELAY=0 $EMERGER -y -nl -nc -nt --parallel --only pp
    [ "$status" -eq 0 ]
    [ -e "$HOME/flaked" ]
    grep -q "step: retry 1" "$EMERGER_STATE/emerger.log"
}
