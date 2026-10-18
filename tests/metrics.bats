#!/usr/bin/env bats

load test_helper

setup() {
    setup_home
    export EMERGER_STATE="$HOME/state"
    mkdir -p "$EMERGER_STATE"
}

teardown() {
    teardown_home
}

# Export metrics from a history whose last line is $1.
export_with() {
    echo "$1" >"$EMERGER_STATE/history.jsonl"
    bash -c 'set -Eeuo pipefail; source "$LIB/load.sh" ui history metrics; metrics_export "$HOME/m.prom"'
}

@test "metrics: a run with no managers still writes every gauge" {
    run export_with '{"ts":"2026-01-01T00:00:00Z","duration":3,"freed_kb":2,"errors":0,"reboot":1,"managers":[]}'
    [ "$status" -eq 0 ]
    grep -qx 'emerger_last_run_duration_seconds 3' "$HOME/m.prom"
    grep -qx 'emerger_last_run_freed_bytes 2048' "$HOME/m.prom"
    grep -qx 'emerger_reboot_required 1' "$HOME/m.prom"
    [ -z "$(ls "$HOME" | grep 'm.prom.')" ]
}

@test "metrics: one gauge per manager with its result" {
    run export_with '{"ts":"2026-01-01T00:00:00Z","duration":3,"freed_kb":0,"errors":1,"reboot":0,"managers":[{"name":"apt","result":"ok"},{"name":"snap","result":"fail"}]}'
    [ "$status" -eq 0 ]
    grep -qx 'emerger_manager_ok{manager="apt"} 1' "$HOME/m.prom"
    grep -qx 'emerger_manager_ok{manager="snap"} 0' "$HOME/m.prom"
    grep -qx 'emerger_last_run_errors 1' "$HOME/m.prom"
}

@test "metrics: the timestamp converts with BSD date too" {
    mkdir -p "$HOME/stubs"
    # BSD date: no -d, -j -f parses. Emulated with GNU date.
    cat >"$HOME/stubs/date" <<'EOS'
#!/bin/bash
[[ $1 == -d ]] && exit 1
if [[ $1 == -j ]]; then exec /bin/date -u -d "$5" "$6"; fi
exec /bin/date "$@"
EOS
    chmod +x "$HOME/stubs/date"
    PATH="$HOME/stubs:$PATH" run export_with '{"ts":"2026-01-01T00:00:00Z","duration":1,"freed_kb":0,"errors":0,"reboot":0,"managers":[]}'
    [ "$status" -eq 0 ]
    grep -qx 'emerger_last_run_timestamp_seconds 1767225600' "$HOME/m.prom"
}

@test "metrics: a symlink planted at the temp name is not followed" {
    unshare -rpf true 2>/dev/null || skip "PID namespaces unavailable"
    echo '{"ts":"2026-01-01T00:00:00Z","duration":5,"freed_kb":1,"errors":0,"reboot":0,"managers":[{"name":"apt","result":"ok"}]}' >"$EMERGER_STATE/history.jsonl"
    echo keep >"$HOME/victim"
    # In a fresh PID namespace the exporting shell is PID 1: plant every name it could pick.
    for pid in 1 2 3; do ln -s "$HOME/victim" "$HOME/out.prom.tmp.$pid"; done
    run unshare -rpf bash -c 'source "$LIB/load.sh" ui history metrics; metrics_export "$HOME/out.prom"'
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/victim")" = keep ]
    grep -q '^emerger_manager_ok{manager="apt"} 1$' "$HOME/out.prom"
    [ "$(stat -c %a "$HOME/out.prom")" = 644 ]
}
