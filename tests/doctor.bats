#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    setup_minbin
}

teardown() {
    teardown_env
}

@test "doctor: long dpkg --audit output is a warning" {
    stub dpkg '[ "$1" = "--audit" ] || exit 0; i=0; while [ $i -lt 20000 ]; do echo "pkg$i half-configured"; i=$((i+1)); done'
    run sys_lib '_doctor_pkg apt; echo "issues=$_DOCTOR_ISSUE_COUNT"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"dpkg --audit reports issues"* ]]
    [[ "$output" == *"issues=1" ]]
    stub dpkg 'exit 0'
    run sys_lib '_doctor_pkg apt; echo "issues=$_DOCTOR_ISSUE_COUNT"'
    [[ "$output" == *"dpkg --audit clean"*"issues=0" ]]
}

@test "doctor: failing dnf check warns, missing subcommand is informational" {
    stub dnf '[ "$1" = check ] && { echo "Problem: foo-1 has missing requires of bar"; exit 1; }'
    run sys_lib '_doctor_pkg dnf; echo "issues=$_DOCTOR_ISSUE_COUNT"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"dnf: check reports problems"* ]]
    [[ "$output" == *"issues=1" ]]
    stub dnf '[ "$1" = check ] && { echo "Unknown argument \"check\" for command \"dnf5\"." >&2; exit 2; }'
    run sys_lib '_doctor_pkg dnf; echo "issues=$_DOCTOR_ISSUE_COUNT"'
    [[ "$output" == *"dnf: check not available"*"issues=0" ]]
    stub dnf 'exit 0'
    run sys_lib '_doctor_pkg dnf; echo "issues=$_DOCTOR_ISSUE_COUNT"'
    [[ "$output" == *"dnf: check ok"*"issues=0" ]]
}

@test "doctor: disk warning follows DISK_MIN_FREE_MB" {
    stub df 'printf "Filesystem 1M-blocks Used Available Capacity Mounted\n/dev/x 9000 1000 1500 50%% /\n"'
    stub sudo 'exit 1'
    run sys_lib 'PKG_MANAGERS=(); DISK_MIN_FREE_MB=2048; doctor_run; echo rc=$?'
    [[ "$output" == *"low disk space on / (1500MB free)"* ]]
    run sys_lib 'PKG_MANAGERS=(); DISK_MIN_FREE_MB=1024; doctor_run; echo rc=$?'
    [[ "$output" == *"disk: 1500MB free on /"* ]]
}
