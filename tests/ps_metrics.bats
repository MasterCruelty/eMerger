#!/usr/bin/env bats
# PowerShell --metrics export, run through pwsh where it is installed.

load ps_helper

@test "ps: --metrics with an empty or malformed last history line exits 1 with a message" {
    mkdir -p "$LOCALAPPDATA/emerger/state"
    printf '{"ts":"2026-01-01T00:00:00Z","duration":5}\n{"ts": broken\n' >"$LOCALAPPDATA/emerger/state/history.jsonl"
    run up_ps '' --metrics "$HOME/m.prom"
    [ "$status" -eq 1 ]
    [[ "$output" == *"last line of"*"history.jsonl is not a valid record"* ]]
    [[ "$output" != *"ConvertFrom-Json"* ]]
    [ ! -e "$HOME/m.prom" ]
    : >"$LOCALAPPDATA/emerger/state/history.jsonl"
    run up_ps '' --metrics "$HOME/m.prom"
    [ "$status" -eq 1 ]
    [[ "$output" == *"history.jsonl is empty"* ]]
}

@test "ps: --metrics never writes through a link planted at a predictable temp name" {
    mkdir -p "$LOCALAPPDATA/emerger/state"
    echo '{"ts":"2026-01-01T00:00:00Z","duration":5,"errors":0,"reboot":0,"managers":[]}' >"$LOCALAPPDATA/emerger/state/history.jsonl"
    echo original >"$HOME/victim"
    ln -s "$HOME/victim" "$HOME/m.prom.tmp"
    run up_ps '' --metrics "$HOME/m.prom"
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/victim")" = original ]
    grep -q '^emerger_last_run_duration_seconds 5$' "$HOME/m.prom"
    [ "$(ls "$HOME" | grep -c '^m\.prom\..*\.tmp$')" -eq 0 ]
}

@test "ps: --metrics fills a missing field with 0 and writes to a path with brackets" {
    run up_ps '' --metrics "$HOME/m.prom"
    [ "$status" -eq 1 ]
    [[ "$output" == *"No history yet ($LOCALAPPDATA/emerger/state/history.jsonl missing)"* ]]
    mkdir -p "$LOCALAPPDATA/emerger/state"
    echo '{"ts":"2026-01-01T00:00:00Z","managers":[{"name":"scoop","result":"ok","secs":1}]}' >"$LOCALAPPDATA/emerger/state/history.jsonl"
    run up_ps '' --metrics "$HOME/m[1].prom"
    [ "$status" -eq 0 ]
    grep -qx 'emerger_last_run_duration_seconds 0' "$HOME/m[1].prom"
    grep -qx 'emerger_last_run_freed_bytes 0' "$HOME/m[1].prom"
    grep -qx 'emerger_last_run_errors 0' "$HOME/m[1].prom"
    grep -qx 'emerger_reboot_required 0' "$HOME/m[1].prom"
    grep -qx '# HELP emerger_manager_ok Per-manager success in the last run (1=ok,0=fail)' "$HOME/m[1].prom"
    grep -qx 'emerger_manager_ok{manager="scoop"} 1' "$HOME/m[1].prom"
}

@test "ps: --metrics writes the freed KiB of the last run as bytes, as on Unix" {
    mkdir -p "$LOCALAPPDATA/emerger/state"
    echo '{"ts":"2026-01-01T00:00:00Z","duration":3,"freed_kb":15,"errors":0,"reboot":0,"managers":[]}' >"$LOCALAPPDATA/emerger/state/history.jsonl"
    run up_ps '' --metrics "$HOME/m.prom"
    [ "$status" -eq 0 ]
    grep -qx '# TYPE emerger_last_run_freed_bytes gauge' "$HOME/m.prom"
    grep -qx 'emerger_last_run_freed_bytes 15360' "$HOME/m.prom"
}
