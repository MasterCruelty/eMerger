# Weekly auto-update through Task Scheduler (--auto-update).

# Register the weekly 'eMerger' scheduled task for the running PowerShell
# host (--auto-update). Return 0, or 1 when registration fails.
function AutoUpdate-Register {
    param([string]$Root)
    UI-Title 'Auto-update (Task Scheduler)'
    if ($script:ArgsGlobal.DryRun) { UI-Sub '[dry-run] would register scheduled task'; return 0 }
    $entry = Join-Path $Root 'src\emerger.ps1'
    try {
        # Host running now (pwsh 7 or Windows PowerShell 5.1), not
        # whichever 'powershell' is on PATH.
        $action = New-ScheduledTaskAction `
            -Execute (Run-PowerShell-Path) `
            -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$entry`" -y -q -nl -ni"
        $trigger = New-ScheduledTaskTrigger -Weekly -DaysOfWeek Sunday -At '10:00'
        $settings = New-ScheduledTaskSettingsSet `
            -StartWhenAvailable `
            -RunOnlyIfNetworkAvailable `
            -RandomDelay (New-TimeSpan -Hours 1) `
            -DontStopOnIdleEnd
        $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive
        Register-ScheduledTask -TaskName 'eMerger' -Action $action -Trigger $trigger -Settings $settings -Principal $principal `
            -Description 'Weekly eMerger update' -Force | Out-Null
        UI-Ok "Scheduled task 'eMerger' created (weekly, Sunday 10:00, +/-1h delay)"
        UI-Muted "Manage with: Get-ScheduledTask eMerger | Select-Object State,LastRunTime"
        return 0
    } catch {
        UI-Err "Failed to register task: $($_.Exception.Message)"
        return 1
    }
}
