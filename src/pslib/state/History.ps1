# Run history: the history.jsonl append and the --history viewer.

# Append JSON line $Line to history.jsonl, keeping the last 500 lines.
function History-Append {
    param([string]$Line)
    $historyPath = Join-Path $script:EMERGER_STATE 'history.jsonl'
    try {
        Add-Content -LiteralPath $historyPath -Value $Line -ErrorAction Stop
        # Rotate at 500 lines, read finished before the write (see Log-Init).
        $count = (Get-Content -LiteralPath $historyPath | Measure-Object).Count
        if ($count -gt 500) { (Get-Content -LiteralPath $historyPath -Tail 500) | Set-Content -LiteralPath $historyPath }
    } catch {}
}

# Print the last 10 runs of history.jsonl (--history).
function History-Show {
    $historyPath = Join-Path $script:EMERGER_STATE 'history.jsonl'
    if (-not (Test-Path -LiteralPath $historyPath)) { UI-Muted 'No history yet.'; return }
    UI-Title 'Recent runs'
    Get-Content -LiteralPath $historyPath -Tail 10 | ForEach-Object {
        try {
            $record = $_ | ConvertFrom-Json
            $reboot = if ($record.reboot -eq 1) { ' ' + (UI-Color yellow 'reboot') } else { '' }
            if ($record.errors -gt 0) {
                Write-Host "  $(UI-Color red (UI-Glyph cross)) $($record.ts)  $($record.duration)s  $(UI-Color yellow "errors=$($record.errors)")$reboot"
            } else {
                Write-Host "  $(UI-Color green (UI-Glyph check)) $($record.ts)  $($record.duration)s$reboot"
            }
        } catch {}
    }
}
