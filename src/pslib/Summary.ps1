# Final summary box, history persistence, errors/history viewers.

$script:SUMMARY_FREED_MB = 0

function Summary-Json {
    param([int]$Duration)
    $obj = [pscustomobject]@{
        ts        = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        duration  = $Duration
        errors    = @($script:Summary | Where-Object { $_.Result -eq 'fail' }).Count
        freed_mb  = $script:SUMMARY_FREED_MB
        reboot    = [int](Reboot-Pending)
        managers  = @($script:Summary | ForEach-Object { [pscustomobject]@{ name = $_.Name; result = $_.Result } })
    }
    $obj | ConvertTo-Json -Compress -Depth 5
}

function Summary-Print {
    param([int]$Duration)
    if ($script:ArgsGlobal -and $script:ArgsGlobal.Json) {
        Summary-Json $Duration
        _Persist-History $Duration
        return
    }
    if ($script:QUIET_LEVEL -ge 3) { return }

    $min = [int]($Duration / 60)
    $sec = $Duration % 60

    $okCount   = @($script:Summary | Where-Object { $_.Result -eq 'ok'   }).Count
    $failCount = @($script:Summary | Where-Object { $_.Result -eq 'fail' }).Count

    if ($script:QUIET_LEVEL -ge 2) {
        if ($failCount -gt 0) {
            Write-Host "$okCount/$($okCount+$failCount) managers ok, $failCount error(s), ${min}m${sec}s"
        } else {
            Write-Host "$okCount managers ok, ${min}m${sec}s"
        }
        _Persist-History $Duration
        return
    }

    $mgrLine = ''
    foreach ($r in $script:Summary) {
        if ($r.Result -eq 'ok') { $mgrLine += "$(UI-Color green (UI-Glyph check)) $($r.Name)  " }
        else                    { $mgrLine += "$(UI-Color red (UI-Glyph cross)) $($r.Name)  " }
    }

    $lines = @()
    if ($mgrLine) { $lines += $mgrLine; $lines += '' }
    $lines += "duration: ${min}m${sec}s"
    if ($script:SUMMARY_FREED_MB -gt 0) {
        $lines += ("freed:    {0} MB" -f $script:SUMMARY_FREED_MB)
    }
    if ($failCount -gt 0) {
        $lines += (UI-Color yellow "$failCount error(s) - up --errors")
    } else {
        $lines += (UI-Color green 'no errors')
    }

    UI-Box 'eMerger summary' $lines
    _Persist-History $Duration
    Reboot-Advisory
}

function _Persist-History {
    param([int]$Duration)
    $hist = Join-Path $script:EMERGER_STATE 'history.jsonl'
    $obj = [pscustomobject]@{
        ts        = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
        duration  = $Duration
        errors    = @($script:Summary | Where-Object { $_.Result -eq 'fail' }).Count
        freed_mb  = $script:SUMMARY_FREED_MB
        reboot    = [int](Reboot-Pending)
        managers  = @($script:Summary | ForEach-Object { [pscustomobject]@{ name = $_.Name; result = $_.Result } })
    }
    try {
        $line = $obj | ConvertTo-Json -Compress -Depth 5
        Add-Content -Path $hist -Value $line -ErrorAction Stop
        # rotate
        $count = (Get-Content $hist | Measure-Object).Count
        if ($count -gt 500) { Get-Content $hist -Tail 500 | Set-Content $hist }
    } catch {}
}

function Reboot-Pending {
    # Several signals can indicate a pending reboot on Windows.
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
        'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations'
    )
    foreach ($k in $keys) {
        if (Test-Path $k) { return $true }
    }
    return $false
}

function Reboot-Advisory {
    if (Reboot-Pending) {
        Write-Host ("`n  $(UI-Color yellow (UI-Glyph warn)) $(UI-Color yellow 'REBOOT RECOMMENDED')  $(UI-Color gray '(pending updates require restart)')")
        Write-Host ("  $(UI-Color gray 'run:') Restart-Computer")
    }
}

function Show-Errors {
    $log = Join-Path $script:EMERGER_STATE 'emerger.log'
    if (-not (Test-Path $log)) { UI-Ok 'no log yet'; return }
    $errs = @(Select-String -Path $log -Pattern '\|ERROR\|' -ErrorAction SilentlyContinue)
    if ($errs.Count -eq 0) { UI-Ok 'no errors logged'; return }
    UI-Warn "$($errs.Count) error line(s):"
    $errs | Select-Object -Last 30 | ForEach-Object { Write-Host "  $($_.Line)" }
}

function Show-History {
    $hist = Join-Path $script:EMERGER_STATE 'history.jsonl'
    if (-not (Test-Path $hist)) { UI-Muted 'no history yet'; return }
    UI-Title 'Recent runs'
    Get-Content $hist -Tail 10 | ForEach-Object {
        try {
            $o = $_ | ConvertFrom-Json
            $reboot = if ($o.reboot -eq 1) { ' ' + (UI-Color yellow 'reboot') } else { '' }
            if ($o.errors -gt 0) {
                Write-Host "  $(UI-Color red (UI-Glyph cross)) $($o.ts)  $($o.duration)s  $(UI-Color yellow "errors=$($o.errors)")$reboot"
            } else {
                Write-Host "  $(UI-Color green (UI-Glyph check)) $($o.ts)  $($o.duration)s$reboot"
            }
        } catch {}
    }
}
