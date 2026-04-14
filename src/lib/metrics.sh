#!/usr/bin/env bash
# Prometheus textfile-collector export.
# Reads the most recent entry of history.jsonl and renders a .prom file.

metrics_export() {
    local out="$1"
    local hist="$EMERGER_STATE/history.jsonl"
    if [[ ! -f $hist ]]; then
        ui_err "No history yet ($hist missing)"
        return 1
    fi
    local last
    last=$(tail -n 1 "$hist")
    [[ -z $last ]] && { ui_err "history.jsonl is empty"; return 1; }

    local ts dur freed errs reboot
    ts=$(printf '%s' "$last" | sed -n 's/.*"ts":"\([^"]*\)".*/\1/p')
    dur=$(printf '%s' "$last" | sed -n 's/.*"duration":\([0-9]*\).*/\1/p')
    freed=$(printf '%s' "$last" | sed -n 's/.*"freed_kb":\([0-9]*\).*/\1/p')
    errs=$(printf '%s' "$last" | sed -n 's/.*"errors":\([0-9]*\).*/\1/p')
    reboot=$(printf '%s' "$last" | sed -n 's/.*"reboot":\([0-9]*\).*/\1/p')

    # epoch (best-effort, GNU date syntax).
    local epoch=0
    if [[ -n $ts ]]; then
        epoch=$(date -d "$ts" +%s 2>/dev/null || echo 0)
    fi

    local tmp="$out.tmp.$$"
    {
        printf '# HELP emerger_last_run_timestamp_seconds Unix timestamp of the last eMerger run\n'
        printf '# TYPE emerger_last_run_timestamp_seconds gauge\n'
        printf 'emerger_last_run_timestamp_seconds %s\n' "${epoch:-0}"
        printf '# HELP emerger_last_run_duration_seconds Duration of the last run\n'
        printf '# TYPE emerger_last_run_duration_seconds gauge\n'
        printf 'emerger_last_run_duration_seconds %s\n' "${dur:-0}"
        printf '# HELP emerger_last_run_freed_bytes Bytes freed by the last run\n'
        printf '# TYPE emerger_last_run_freed_bytes gauge\n'
        printf 'emerger_last_run_freed_bytes %s\n' "$(( ${freed:-0} * 1024 ))"
        printf '# HELP emerger_last_run_errors Manager failures in the last run\n'
        printf '# TYPE emerger_last_run_errors gauge\n'
        printf 'emerger_last_run_errors %s\n' "${errs:-0}"
        printf '# HELP emerger_reboot_required Whether a reboot is pending (0/1)\n'
        printf '# TYPE emerger_reboot_required gauge\n'
        printf 'emerger_reboot_required %s\n' "${reboot:-0}"

        # Per-manager success flag.
        printf '# HELP emerger_manager_ok Per-manager success in the last run (1=ok,0=fail)\n'
        printf '# TYPE emerger_manager_ok gauge\n'
        printf '%s\n' "$last" | grep -oE '"name":"[^"]*","result":"[^"]*"' | \
            while IFS= read -r pair; do
                local name result val
                name=$(printf '%s' "$pair" | sed -n 's/.*"name":"\([^"]*\)".*/\1/p')
                result=$(printf '%s' "$pair" | sed -n 's/.*"result":"\([^"]*\)".*/\1/p')
                val=0
                [[ $result == ok ]] && val=1
                printf 'emerger_manager_ok{manager="%s"} %s\n' "$name" "$val"
            done
    } >"$tmp"
    mv "$tmp" "$out"
    ui_ok "metrics written to $out"
}
