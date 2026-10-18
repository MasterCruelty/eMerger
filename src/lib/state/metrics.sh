#!/usr/bin/env bash
# Prometheus textfile-collector export.
# Reads the most recent entry of history.jsonl and renders a .prom file.

# Write the last history.jsonl run as Prometheus textfile gauges to path $1,
# replaced atomically and readable by all. Return 1 without history or when the file cannot be written.
metrics_export() {
    local out="$1"
    local history="$EMERGER_STATE/history.jsonl"
    if [[ ! -f $history ]]; then
        ui_err "No history yet ($history missing)"
        return 1
    fi
    local last
    last=$(tail -n 1 "$history")
    [[ -z $last ]] && { ui_err "history.jsonl is empty"; return 1; }

    local timestamp duration freed errors reboot
    timestamp=$(history_text "$last" ts)
    duration=$(history_field "$last" duration)
    freed=$(history_field "$last" freed_kb)
    errors=$(history_field "$last" errors)
    reboot=$(history_field "$last" reboot)

    # Epoch seconds: GNU date first, then the BSD form macOS ships.
    local epoch=0
    if [[ -n $timestamp ]]; then
        epoch=$(date -d "$timestamp" +%s 2>/dev/null \
            || date -j -u -f '%Y-%m-%dT%H:%M:%SZ' "$timestamp" +%s 2>/dev/null \
            || echo 0)
    fi

    # Fresh random name beside the target, so nothing planted there is followed.
    local tmp
    tmp=$(mktemp "$out.XXXXXX") || { ui_err "cannot write beside $out"; return 1; }
    _metrics_render >"$tmp"
    # Textfile collectors usually run as another user: keep the file readable.
    chmod 0644 "$tmp"
    mv "$tmp" "$out"
    ui_ok "metrics written to $out"
}

# Print the textfile-collector gauges of metrics_export's locals: epoch, duration,
# freed (KiB), errors, reboot and the history line last for the per-manager
# results.
_metrics_render() {
    printf '# HELP emerger_last_run_timestamp_seconds Unix timestamp of the last eMerger run\n'
    printf '# TYPE emerger_last_run_timestamp_seconds gauge\n'
    printf 'emerger_last_run_timestamp_seconds %s\n' "${epoch:-0}"
    printf '# HELP emerger_last_run_duration_seconds Duration of the last run\n'
    printf '# TYPE emerger_last_run_duration_seconds gauge\n'
    printf 'emerger_last_run_duration_seconds %s\n' "${duration:-0}"
    printf '# HELP emerger_last_run_freed_bytes Bytes freed by the last run\n'
    printf '# TYPE emerger_last_run_freed_bytes gauge\n'
    printf 'emerger_last_run_freed_bytes %s\n' "$(( ${freed:-0} * 1024 ))"
    printf '# HELP emerger_last_run_errors Manager failures in the last run\n'
    printf '# TYPE emerger_last_run_errors gauge\n'
    printf 'emerger_last_run_errors %s\n' "${errors:-0}"
    printf '# HELP emerger_reboot_required Whether a reboot is pending (0/1)\n'
    printf '# TYPE emerger_reboot_required gauge\n'
    printf 'emerger_reboot_required %s\n' "${reboot:-0}"

    # Per-manager success flag.
    printf '# HELP emerger_manager_ok Per-manager success in the last run (1=ok,0=fail)\n'
    printf '# TYPE emerger_manager_ok gauge\n'
    # No managers means no match: grep exits 1, which is not an error here.
    printf '%s\n' "$last" | { grep -oE '"name":"[^"]*","result":"[^"]*"' || true; } | \
        while IFS= read -r pair; do
            local name result value
            name=$(history_text "$pair" name)
            result=$(history_text "$pair" result)
            value=0
            [[ $result == ok ]] && value=1
            printf 'emerger_manager_ok{manager="%s"} %s\n' "$name" "$value"
        done
}
