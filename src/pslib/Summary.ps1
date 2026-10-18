# Final summary: the run as one JSON line, and the summary box.

# KiB freed by the cache and trash cleaning of this run.
$script:SUMMARY_FREED_KB = 0

# Count the managers that failed in this run.
function Summary-Fail-Count {
    return @($script:Summary | Where-Object { $_.Result -eq 'fail' }).Count
}

# Return the run of $Duration seconds as one JSON line: the --json output and
# the history.jsonl entry. Estimate-Read reads back its per-manager secs.
function Summary-Json {
    param([int]$Duration)
    $run = [pscustomobject]@{
        ts        = Log-Timestamp
        duration  = $Duration
        errors    = Summary-Fail-Count
        freed_kb  = [int64]$script:SUMMARY_FREED_KB
        reboot    = [int](Reboot-Pending)
        managers  = @($script:Summary | ForEach-Object { [pscustomobject]@{ name = $_.Name; result = $_.Result; secs = [int]$_.Secs } })
    }
    $run | ConvertTo-Json -Compress -Depth 5
}

# Close the run of $Duration seconds: append the history line (not on a dry
# run), then print what
# the quiet level allows: the JSON line, a one-line tally (-qq), nothing
# (-qqq) or the summary box.
function Summary-Print {
    param([int]$Duration)
    $line = Summary-Json $Duration
    if (-not ($script:ArgsGlobal -and $script:ArgsGlobal.DryRun)) { History-Append $line }
    if ($script:ArgsGlobal -and $script:ArgsGlobal.Json) {
        $line
        return
    }
    if ($script:QUIET_LEVEL -ge 3) { return }

    $minutes = [int][math]::Floor($Duration / 60)
    $seconds = $Duration % 60

    $okCount   = @($script:Summary | Where-Object { $_.Result -eq 'ok'   }).Count
    $failCount = Summary-Fail-Count

    if ($script:QUIET_LEVEL -ge 2) {
        if ($failCount -gt 0) {
            Write-Host ("{0}/{1} managers ok, {2} error(s), {3}m{4:00}s" -f $okCount, ($okCount + $failCount), $failCount, $minutes, $seconds)
        } else {
            Write-Host ("{0} managers ok, {1}m{2:00}s" -f $okCount, $minutes, $seconds)
        }
        Reboot-Advisory
        return
    }

    $keyLabel = { param($name) UI-Color 'dim gray' ($name.PadRight(9)) }
    $managerParts = @()
    foreach ($entry in $script:Summary) {
        if ($entry.Result -eq 'ok') { $managerParts += ((UI-Color green (UI-Glyph check)) + " $($entry.Name)") }
        else                    { $managerParts += ((UI-Color red (UI-Glyph cross)) + ' ' + (UI-Color red $entry.Name)) }
    }

    $lines = @()
    if ($managerParts.Count -gt 0) { $lines += ((& $keyLabel 'managers') + ' ' + ($managerParts -join '  ')) }
    $lines += ((& $keyLabel 'time') + ' ' + (UI-Color bold ('{0}m{1:00}s' -f $minutes, $seconds)))
    if ($script:SUMMARY_FREED_KB -gt 0) {
        $lines += ((& $keyLabel 'freed') + ' ' + (UI-Color cyan (Size-Format-KB $script:SUMMARY_FREED_KB)))
    }
    if ($script:PKG_CHANGED -gt 0) {
        $lines += ((& $keyLabel 'changed') + " $($script:PKG_CHANGED) packages")
    }
    if ($failCount -gt 0) {
        $lines += ((& $keyLabel 'status') + ' ' + (UI-Color 'bold yellow' "$(UI-Glyph warn) $failCount error(s)") + '  ' + (UI-Color 'dim gray' '(up --errors)'))
    } else {
        $lines += ((& $keyLabel 'status') + ' ' + (UI-Color 'bold green' "$(UI-Glyph check) all good"))
    }

    $boxColor = if ($failCount -gt 0) { 'yellow' } else { 'green' }
    UI-Box 'eMerger summary' $lines $boxColor
    Reboot-Advisory
}
