#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    # Managers the tests rely on, so detection does not depend on the host.
    for m in apt snap; do printf '#!/bin/sh\nexit 0\n' >"$STUBS/$m"; chmod +x "$STUBS/$m"; done
    printf '#!/bin/sh\necho "sudo $*" >>"$HOME/sudo.log"\n' >"$STUBS/sudo"; chmod +x "$STUBS/sudo"
}

teardown() {
    teardown_env
}

@test "history shows placeholder when empty" {
    run $EMERGER --history
    [ "$status" -eq 0 ]
}

@test "history lists each run with its time, duration, errors and reboot" {
    mkdir -p "$XDG_STATE_HOME/emerger"
    printf '%s\n' '{"ts":"2026-01-02T03:04:05Z","duration":42,"freed_kb":0,"errors":0,"reboot":0,"managers":[]}' \
        '{"ts":"2026-01-03T03:04:05Z","duration":7,"freed_kb":0,"errors":2,"reboot":1,"managers":[]}' \
        >"$XDG_STATE_HOME/emerger/history.jsonl"
    run $EMERGER --history --ascii
    [ "$status" -eq 0 ]
    [ "${lines[1]}" = "  [OK] 2026-01-02T03:04:05Z  42s" ]
    [ "${lines[2]}" = "  [X] 2026-01-03T03:04:05Z  7s  errors=2 reboot" ]
}

@test "--metrics refuses with empty history" {
    run $EMERGER --metrics "$HOME/out.prom"
    [ "$status" -eq 1 ]
    [[ "$output" == *"No history yet"* ]]
    [ ! -e "$HOME/out.prom" ]
}

@test "estimate: per-manager seconds, not the whole-run duration" {
    mkdir -p "$EMERGER_STATE"
    echo '{"ts":"2026-01-01T00:00:00Z","duration":600,"freed_kb":0,"errors":0,"reboot":0,"managers":[{"name":"apt","result":"ok","secs":30},{"name":"flatpak","result":"ok","secs":570}]}' >"$EMERGER_STATE/history.jsonl"
    run lib 'echo "[$(estimate_for apt)] [$(estimate_for flatpak)] [$(estimate_for ok)] [$(estimate_for snap)]"'
    [ "$output" = "[~30s] [~9m30s] [] []" ]
}

@test "estimate: averages the last runs and ignores lines without secs" {
    mkdir -p "$EMERGER_STATE"
    {
        echo '{"duration":900,"managers":[{"name":"apt","result":"ok"}]}'
        echo '{"duration":50,"managers":[{"name":"apt","result":"ok","secs":10}]}'
        echo '{"duration":50,"managers":[{"name":"apt","result":"fail","secs":20}]}'
    } >"$EMERGER_STATE/history.jsonl"
    run lib 'estimate_for apt'
    [ "$output" = "~15s" ]
}

@test "history: each manager carries its seconds" {
    plugin pa ''
    run $EMERGER -y -nl -nc -nt --only pa
    [ "$status" -eq 0 ]
    [[ "$(tail -n 1 "$EMERGER_STATE/history.jsonl")" =~ \"name\":\"pa\",\"result\":\"ok\",\"secs\":[0-9]+ ]]
}

@test "errors: a UTF-8 log line shown on a non-UTF-8 terminal loses its bytes above 0x7F" {
    mkdir -p "$XDG_STATE_HOME/emerger"
    printf '2026-01-01T00:00:00Z|ERROR|caf\xc3\x9b31m\n' >"$XDG_STATE_HOME/emerger/emerger.log"
    run env LANG=C LC_ALL=C $EMERGER --errors
    [ "$status" -eq 0 ]
    [[ "$output" == *"caf31m"* ]]
}
