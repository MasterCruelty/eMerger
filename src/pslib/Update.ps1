# Self-update (git) and auto-update (Task Scheduler).

function Self-Update {
    param([string]$Root)
    UI-Title 'Self-update'
    if (-not (Test-Path (Join-Path $Root '.git'))) {
        UI-Err 'Not a git checkout. Re-clone from https://github.com/MasterCruelty/eMerger'
        return 1
    }
    if (-not (Sys-Has git)) { UI-Err 'git not installed'; return 1 }
    if ($script:ArgsGlobal.DryRun) { UI-Sub "[dry-run] git -C `"$Root`" pull --ff-only"; return 0 }
    $before = (& git -C $Root rev-parse HEAD 2>$null).Trim()
    & git -C $Root fetch --quiet 2>$null
    & git -C $Root pull --ff-only --quiet 2>$null
    if ($LASTEXITCODE -ne 0) {
        UI-Err 'git pull failed (non fast-forward?)'
        return 1
    }
    $after = (& git -C $Root rev-parse HEAD 2>$null).Trim()
    if ($before -eq $after) {
        UI-Ok 'Already up to date.'
    } else {
        UI-Ok ("Updated {0}..{1}" -f $before.Substring(0, [math]::Min(7,$before.Length)), $after.Substring(0, [math]::Min(7,$after.Length)))
        & git -C $Root log --oneline "$before..$after" | ForEach-Object { Write-Host "    $(UI-Color gray (UI-Glyph dot)) $_" }
    }
    return 0
}

function Setup-Task {
    param([string]$Root)
    UI-Title 'Auto-update (Task Scheduler)'
    if ($script:ArgsGlobal.DryRun) { UI-Sub '[dry-run] would register scheduled task'; return 0 }
    $entry = Join-Path $Root 'src\emerger.ps1'
    try {
        $action = New-ScheduledTaskAction `
            -Execute 'powershell' `
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
        UI-Ok "Scheduled task 'eMerger' created (weekly, Sunday 10:00, ±1h delay)"
        UI-Muted "Manage with: Get-ScheduledTask eMerger | Select-Object State,LastRunTime"
        return 0
    } catch {
        UI-Err "Failed to register task: $($_.Exception.Message)"
        return 1
    }
}
