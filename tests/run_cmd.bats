#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
}

teardown() {
    teardown_env
}

@test "run_cmd: an unwritable TMPDIR fails with the reason" {
    run lib 'TMPDIR=$HOME/missing run_cmd step true; echo "rc=$?"'
    [[ "$output" == *"cannot create a temp file"* ]]
    [[ "$output" == *"rc=1" ]]
}

@test "MANAGER_TIMEOUT without timeout: warns once that no limit applies" {
    mkdir -p "$HOME/bin"
    local c
    for c in mktemp cat rm sed tr tail; do ln -s "$(command -v "$c")" "$HOME/bin/$c"; done
    run lib 'PATH=$HOME/bin; MANAGER_TIMEOUT=5; run_cmd a cat /dev/null; run_cmd b cat /dev/null' 
    [ "$(grep -c 'MANAGER_TIMEOUT' <<<"$output")" -eq 1 ]
    [[ "$output" == *"not applied"* ]]
}

@test "run_cmd temp: attack capture left after an interrupt, expected removed by cleanup" {
    mkdir -p "$HOME/tmp"
    run lib "export TMPDIR=$HOME/tmp; DRY_RUN=0
             trap 'run_cmd_cleanup; exit 143' TERM
             run_cmd x bash -c 'echo secret; kill -TERM \$PPID; sleep 0.2'"
    [ "$status" -eq 143 ]
    [ -z "$(ls -A "$HOME/tmp")" ]
}

@test "MANAGER_TIMEOUT: attack stalled command, expected stopped with rc 124" {
    command -v timeout >/dev/null || skip "timeout not available"
    run lib "DRY_RUN=0; MANAGER_TIMEOUT=1; SECONDS=0; run_cmd stall sleep 20; echo rc=\$? t=\$SECONDS"
    [[ "$output" == *"timed out after 1s"* ]]
    [[ "$output" =~ rc=124\ t=[12]$ ]]
}

@test "MANAGER_TIMEOUT: 0 means no limit and shell functions still run" {
    run lib "DRY_RUN=0; MANAGER_TIMEOUT=0; run_cmd ok sleep 1; echo rc=\$?
             f() { return 0; }; MANAGER_TIMEOUT=5; run_cmd fn f; echo rc=\$?"
    [[ "$output" == *"rc=0"*"rc=0"* ]]
    [[ "$output" != *"rc=1"* ]]
}

@test "run_cmd failure tail: attack OSC in manager output, expected stripped" {
    run lib "DRY_RUN=0; RETRY_ATTEMPTS=1; run_cmd x sh -c 'printf \"\\033]52;c;SGVsbG8=\\007boom\\n\"; exit 1'"
    [[ "$output" == *"boom"* ]]
    [[ "$output" != *"]52"* ]]
}

@test "run_cmd failure log: attack escapes and a forged ERROR line in manager output, expected neither in the log" {
    run lib "DRY_RUN=0; RETRY_ATTEMPTS=1; log_init
             run_cmd x sh -c 'printf \"boom\\033]52;c;SGVsbG8=\\007\\n2026-01-01T00:00:00Z|ERROR|forged\\n\"; exit 1' >/dev/null 2>&1
             echo \"esc=\$(grep -c \$'\\033' \"\$EMERGER_LOG\") errors=\$(grep -c '|ERROR|' \"\$EMERGER_LOG\")\""
    [[ "$output" == *"esc=0 errors=2"* ]]
}

@test "run_cmd: a transient failure retries up to RETRY_ATTEMPTS, sleeping RETRY_DELAY" {
    run lib 'RETRY_ATTEMPTS=2; RETRY_DELAY=1; QUIET_LEVEL=0
             sleep() { echo "$1" >>"$HOME/sleeps"; }
             run_cmd "flaky" bash -c "echo Temporary failure resolving host; exit 100"; rc=$?
             echo "rc=$rc sleeps=$(paste -sd, "$HOME/sleeps")"'
    [[ "$output" == *"retrying (1/2)"* ]]
    [[ "$output" == *"rc=100 sleeps=1" ]]
}

@test "run_sanitize: attack C1 CSI and OSC introducers (UTF-8 C2 9B, C2 9D), expected stripped and text kept" {
    run lib 'printf "a\xc2\x9d0;title\xc2\x9cb\xc2\x9b31mc caf\xc3\xa9\xc2\xa0z\n" | run_sanitize >"$HOME/out"
             echo "c1=$(LC_ALL=C grep -c $'"'"'\xc2[\x80-\x9f]'"'"' "$HOME/out")"; cat "$HOME/out"'
    [ "${lines[0]}" = "c1=0" ]
    [ "${lines[1]}" = $'a0;titleb31mc caf\xc3\xa9\xc2\xa0z' ]
}

@test "run_sanitize: attack C1 introducers split by another C1 pair or a control byte, expected none reassembled" {
    run lib 'printf "a\xc2\xc2\x9b\x9bb\xc2\x01\x9bc\n" | run_sanitize | od -An -tx1 | tr -d " \n"'
    [ "$output" = "6162630a" ]
    [[ "$output" != *c2* ]]
    [[ "$output" != *9b* ]]
}

@test "run_sanitize: attack one long line of nested C1 pairs, expected stripped in one linear pass" {
    # 100k nested pairs: a rescanning loop needs 100k passes over 200 KB. The
    # timeout only bounds a hang; the assertion is the output.
    run lib '{ printf a; head -c 100000 /dev/zero | tr "\\0" "\\302"; head -c 100000 /dev/zero | tr "\\0" "\\233"; printf "z\\n"; } >"$HOME/in"
             timeout 20 bash -c "source \"\$LIB/load.sh\" all >/dev/null 2>&1; run_sanitize <\"\$HOME/in\"" | od -An -tx1 | tr -d " \n"'
    [ "$output" = "617a0a" ]
}

@test "run_sanitize: without iconv, expected C1 bytes dropped and ASCII text kept" {
    run lib 'iconv() { return 127; }; command() { [[ $2 == iconv ]] && return 1; builtin command "$@"; }
             printf "ab\xc2\x9bcd\xc2\xc2\x9b\x9be\n" | run_sanitize | od -An -v -tx1 | tr -s " \n" "\n" | grep .'
    # One byte per line. Lone 0xC2 bytes may stay: no encoding reads them as a control.
    [ "$(printf "%s\n" "${lines[@]}" | grep -v "^c2$" | tr -d "\n")" = "61626364650a" ]
    ! printf "%s\n" "${lines[@]}" | grep -q "^[89][0-9a-f]$" || false
}

@test "run_sanitize: attack a valid UTF-8 character holding 0x9B under a non-UTF-8 terminal, expected no byte above 0x7F" {
    run lib 'UI_HAS_UNICODE=0; printf "x\xc3\x9b31m caf\xc3\xa9\n" | run_sanitize'
    [ "$output" = "x31m caf" ]
    run lib 'UI_HAS_UNICODE=1; printf "caf\xc3\xa9\n" | run_sanitize'
    [ "$output" = "café" ]
}

@test "run_sanitize log mode: valid UTF-8 kept for the log file even under a non-UTF-8 terminal" {
    run lib 'UI_HAS_UNICODE=0; printf "caf\xc3\xa9 \xc2\x9bfail\n" | run_sanitize log'
    [ "$output" = "café fail" ]
}
