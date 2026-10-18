#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
}

teardown() {
    teardown_env
}

@test "monitor: stop returns only after the monitor exited" {
    run lib 'UI_IS_TTY=1; ui_monitor_start lbl /dev/null >/dev/null; p=$_MONITOR_PID; sleep 0.35
             ui_monitor_stop >/dev/null; if kill -0 "$p" 2>/dev/null; then echo alive; else echo gone; fi'
    [ "$output" = "gone" ]
}

@test "monitor: exits once the main process is killed" {
    bash -c 'set -uo pipefail; source "$LIB/load.sh" ui log sys progress run
             UI_IS_TTY=1; ui_monitor_start lbl /dev/null; echo "$_MONITOR_PID" >"$HOME/m.pid"; sleep 30' >/dev/null 2>&1 &
    local parent=$!
    sleep 1
    kill -9 "$parent"
    sleep 3
    local m; m=$(cat "$HOME/m.pid")
    run kill -0 "$m"
    kill "$m" 2>/dev/null || true
    [ "$status" -ne 0 ]
}

@test "monitor: a partial line is shown after 2 s without output" {
    run lib 'f=$(mktemp); printf "Overwrite config? [y/N] " >"$f"
             UI_IS_TTY=1; ui_monitor_start lbl "$f" >"$HOME/mon.out"
             # Wait for the frame, bounded: a loaded machine draws frames late.
             for (( i = 0; i < 600; i++ )); do
                 grep -qF "Overwrite config?" "$HOME/mon.out" && break; sleep 0.1
             done
             ui_monitor_stop >/dev/null
             cat "$HOME/mon.out"'
    [[ "$output" == *"Overwrite config? [y/N]"* ]]
}

@test "monitor: attack OSC in manager output, expected stripped from the live line" {
    run lib "printf 'x\033]52;c;SGVsbG8=\007end\n' >$HOME/m.log; UI_IS_TTY=1
             ui_monitor_start lbl $HOME/m.log; sleep 0.5; ui_monitor_stop"
    [[ "$output" == *"xend"* ]]
    [[ "$output" != *"]52"* ]]
    [[ "$output" != *$'\a'* ]]
}

@test "monitor: attack 160 KB of CSI in one line, expected cleaned within the time bound" {
    run lib 'timeout 20 bash -c "source \"\$LIB/load.sh\" ui
             line=\$(printf \"\\033[1m%.0s\" \$(seq 40000))
             _ui_clean_line \"\$line\"; echo len=\${#_UI_CLEANED}"; echo rc=$?'
    [[ "$output" == *"len=0"* ]]
    [[ "$output" == *"rc=0"* ]]
}

@test "monitor: line cleaning removes CSI, OSC with either terminator and control bytes" {
    run lib "_ui_clean_line \$'a\\e[1;31mb\\e]0;t\\acd\\e]8;;u\\e\\\\ef\\x01g\\rh\\e[?25li'; echo \"[\$_UI_CLEANED]\""
    [ "$output" = "[hi]" ]
    run lib "_ui_clean_line \$'a\\e[1;31mb\\e]0;t\\acd\\e]8;;u\\e\\\\ef\\x01g'; echo \"[\$_UI_CLEANED]\""
    [ "$output" = "[abcdefg]" ]
}

@test "monitor: line cleaning keeps at most 1024 characters" {
    run lib 'l=$(printf "x%.0s" $(seq 3000)); _ui_clean_line "$l"; echo "len=${#_UI_CLEANED}"'
    [ "$output" = "len=1024" ]
}

@test "monitor: attack C1 introducers (UTF-8 C2 9B, C2 9D) in a line, expected stripped under UTF-8 and C locales" {
    local loc
    for loc in C.UTF-8 C; do
        run env LC_ALL=$loc bash -c 'source "$1/load.sh" ui
            _ui_clean_line $'"'"'x\xc2\x9d0;t\xc2\x9cy\xc2\x9b31m caf\xc3\xa9\xc2\xa0'"'"'
            printf "%s" "$_UI_CLEANED" | od -An -c | tr -s " "
            printf "[%s]\n" "${LC_ALL-unset}"' _ "$LIB"
        [[ "$output" != *'302 235'* && "$output" != *'302 234'* && "$output" != *'302 233'* ]]
        if [[ $loc == C.UTF-8 ]]; then
            [[ "$output" == *'x 0 ; t y 3 1 m'*'303 251 302 240'* ]]
        else
            # A C locale means a terminal outside UTF-8: every byte above 0x7F goes.
            [[ "$output" == *'x 0 ; t y 3 1 m c a f'* && "$output" != *'303'* ]]
        fi
        [[ "$output" == *"[$loc]" ]]
    done
}

@test "monitor: attack C1 introducers split by another C1 pair or a control byte, expected none reassembled" {
    run lib '_ui_clean_line $'"'"'a\xc2\xc2\x9b\x9bb\xc2\x01\x9bc'"'"'; printf %s "$_UI_CLEANED" | od -An -tx1 | tr -d " \n"'
    [[ "$output" != *c2* ]]
    [[ "$output" != *9b* ]]
}

@test "monitor: C1 pairs are stripped byte-wise even under a UTF-8 locale" {
    run lib 'export LANG=C.UTF-8 LC_ALL=C.UTF-8; _ui_clean_line $'"'"'x\xc2\x9by'"'"'; printf %s "$_UI_CLEANED"'
    [ "$output" = "xy" ]
}

@test "monitor: attack one 400 KB line, expected cleaned without a quadratic scan" {
    # The timeout only bounds a hang; the assertion is the output.
    run timeout 20 bash -c 'source "$LIB/load.sh" ui >/dev/null
             l=$(head -c 400000 /dev/zero | tr "\0" "x")
             _ui_clean_line "$l"; echo "${#_UI_CLEANED}"'
    [ "$output" = "1024" ]
}

@test "monitor: attack a lone 0x9B byte under a non-UTF-8 terminal, expected no byte above 0x7F shown" {
    run lib 'UI_HAS_UNICODE=0; _ui_clean_line $'"'"'a\x9bb\xe9c'"'"'; printf %s "$_UI_CLEANED"'
    [ "$output" = "abc" ]
}

@test "monitor: UTF-8 text stays intact under a UTF-8 terminal" {
    run lib 'UI_HAS_UNICODE=1; _ui_clean_line $'"'"'caf\xc3\xa9'"'"'; printf %s "$_UI_CLEANED"'
    [ "$output" = "café" ]
}

@test "ui: LC_ALL=C wins over a UTF-8 LANG, expected ASCII mode" {
    run bash -c 'export LANG=en_US.UTF-8 LC_ALL=C; source "$LIB/load.sh" ui >/dev/null; echo "$UI_HAS_UNICODE"'
    [ "$output" = "0" ]
    run bash -c 'export LANG=C LC_ALL= LC_CTYPE=en_US.UTF-8; source "$LIB/load.sh" ui >/dev/null; echo "$UI_HAS_UNICODE"'
    [ "$output" = "1" ]
}
