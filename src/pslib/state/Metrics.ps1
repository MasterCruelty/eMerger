# Prometheus textfile export of the last run (--metrics).

# Write the last history.jsonl record to $Path in the Prometheus text format,
# through a temp file beside it. Return 0, or 1 with a message when there is
# no history or its last line is empty or not a record.
function Metrics-Export {
    param([string]$Path)
    $historyPath = Join-Path $script:EMERGER_STATE 'history.jsonl'
    if (-not (Test-Path -LiteralPath $historyPath)) { UI-Err "No history yet ($historyPath missing)"; return 1 }
    $lastLine = "$(Get-Content -LiteralPath $historyPath -Tail 1)"
    if (-not $lastLine.Trim()) { UI-Err "history.jsonl is empty"; return 1 }
    try {
        $last = $lastLine | ConvertFrom-Json
        $epoch = [int64](([DateTime]$last.ts).ToUniversalTime() - [DateTime]'1970-01-01').TotalSeconds
    } catch { UI-Err "last line of $historyPath is not a valid record"; return 1 }
    # Random name beside the target, so nothing can be planted at it.
    $tempPath = "$($Path).$([guid]::NewGuid().ToString('N')).tmp"
    $out = @()
    $out += "# HELP emerger_last_run_timestamp_seconds Unix timestamp of the last eMerger run"
    $out += "# TYPE emerger_last_run_timestamp_seconds gauge"
    $out += "emerger_last_run_timestamp_seconds $epoch"
    $out += "# HELP emerger_last_run_duration_seconds Duration of the last run"
    $out += "# TYPE emerger_last_run_duration_seconds gauge"
    # Missing fields read 0.
    $out += "emerger_last_run_duration_seconds $([int64]$last.duration)"
    $out += "# HELP emerger_last_run_freed_bytes Bytes freed by the last run"
    $out += "# TYPE emerger_last_run_freed_bytes gauge"
    $out += "emerger_last_run_freed_bytes $([int64]$last.freed_kb * 1024)"
    $out += "# HELP emerger_last_run_errors Manager failures in the last run"
    $out += "# TYPE emerger_last_run_errors gauge"
    $out += "emerger_last_run_errors $([int64]$last.errors)"
    $out += "# HELP emerger_reboot_required Whether a reboot is pending (0/1)"
    $out += "# TYPE emerger_reboot_required gauge"
    $out += "emerger_reboot_required $([int64]$last.reboot)"
    $out += "# HELP emerger_manager_ok Per-manager success in the last run (1=ok,0=fail)"
    $out += "# TYPE emerger_manager_ok gauge"
    foreach ($manager in $last.managers) {
        $value = if ($manager.result -eq 'ok') { 1 } else { 0 }
        $out += "emerger_manager_ok{manager=`"$($manager.name)`"} $value"
    }
    $out | Set-Content -LiteralPath $tempPath
    Move-Item -Force -LiteralPath $tempPath -Destination $Path
    UI-Ok "metrics written to $Path"
    return 0
}
