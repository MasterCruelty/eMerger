#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
}

teardown() {
    teardown_env
}

@test "ui_confirm without a tty uses the default" {
    command -v setsid >/dev/null || skip "setsid not available"
    run setsid -w bash -c "source '$LIB/load.sh' ui; ui_confirm 'Q?' n; echo rc=\$?" </dev/null
    [[ "$output" == *"rc=1"* ]]
    run setsid -w bash -c "source '$LIB/load.sh' ui; ui_confirm 'Q?' y; echo rc=\$?" </dev/null
    [[ "$output" == *"rc=0"* ]]
}

@test "ui_confirm times out to the default" {
    command -v script >/dev/null || skip "script not available"
    run bash -c "sleep 3 | script -qfec \"EMERGER_PROMPT_TIMEOUT=1 bash -c 'source $LIB/load.sh ui; ui_confirm Question n; echo rc=\\\$?'\" /dev/null"
    [[ "$output" == *"no answer after 1s"* ]]
    [[ "$output" == *"rc=1"* ]]
}

@test "ui_confirm says yes with -y" {
    run lib 'ARG_YES=1; ui_confirm "Q?" n; echo rc=$?'
    [ "$output" = "rc=0" ]
}

@test "EMERGER_EMOJI=0 gives symbols, 1 gives emoji" {
    run lib 'LANG=C.UTF-8; EMERGER_EMOJI=0; ui_reinit; source "$LIB/load.sh" registry detect icon recipes; pkg_icon apt'
    [ "$output" = "◆" ]
    run lib 'LANG=C.UTF-8; EMERGER_EMOJI=1; ui_reinit; source "$LIB/load.sh" registry detect icon recipes; pkg_icon flatpak'
    [ "$output" = "📦" ]
}

@test "non-UTF-8 locale falls back to ASCII" {
    run lib 'LANG=C LC_ALL=C; ui_reinit; ui_glyph check; ui_glyph hline'
    [ "$output" = "[OK]-" ]
}

@test "progress bar is 10 columns wide" {
    run lib 'LANG=C.UTF-8; ui_reinit; for p in 0 7 55 99 100 140; do ui_bar $p; _ui_strip "$_UI_BAR"; printf "%s " "${#_UI_STRIPPED}"; done'
    [ "$output" = "10 10 10 10 10 10 " ]
    run lib 'LANG=C LC_ALL=C; ui_reinit; ui_bar 50; echo "$_UI_BAR"'
    [ "$output" = "#####-----" ]
}

@test "ui_highlight: adds no escape codes when colours are off, colours error words when on" {
    run bash -c "NO_COLOR=1; source '$LIB/load.sh' ui; printf 'E: boom\nWARNING x\nerror y\n' | ui_highlight"
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf 'E: boom\nWARNING x\nerror y')" ]
    run bash -c "unset NO_COLOR; source '$LIB/load.sh' ui; C_RED=r; C_YELLOW=y; printf 'error y\n' | ui_highlight"
    [[ "$output" == *$'\033[31merror'* ]]
}
