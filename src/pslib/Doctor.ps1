# Environment health check.

# Check the environment (PowerShell, admin, disk, network, execution
# policy, managers, pending reboot) for --doctor. Return 0, or 1 on any issue.
function Doctor-Run {
    UI-Title 'eMerger doctor (Windows)'
    $issues = 0

    UI-Ok "PowerShell $($PSVersionTable.PSVersion)"

    if (Sys-IsAdmin) { UI-Ok 'running as administrator' }
    else             { UI-Info 'not admin (elevation prompted when needed)' }

    # Same threshold as the run's disk precheck.
    $threshold = 1024
    if ("$($script:DISK_MIN_FREE_MB)" -match '^\d{1,9}$') { $threshold = [int]$script:DISK_MIN_FREE_MB }
    $drive = "$env:SystemDrive".TrimEnd(':'); if (-not $drive) { $drive = 'C' }
    $freeMb = Preflight-Disk-Free-MB
    if ($freeMb -lt 0)        { UI-Info "disk: free space on ${drive}: unknown" }
    elseif ($freeMb -lt $threshold) { UI-Warn "low disk space on ${drive}: (${freeMb}MB free, threshold ${threshold}MB)"; $issues++ }
    else                    { UI-Ok  "disk: ${freeMb}MB free on ${drive}:" }

    # HTTPS: github.com drops ICMP, so a ping proves nothing.
    try {
        Invoke-WebRequest -Uri 'https://github.com' -Method Head -TimeoutSec 4 -UseBasicParsing | Out-Null
        UI-Ok 'network: reachable'
    } catch { UI-Warn 'network: github.com unreachable'; $issues++ }

    $policy = Get-ExecutionPolicy -Scope CurrentUser
    if ($policy -eq 'Restricted') { UI-Warn "ExecutionPolicy=$policy (run install.ps1 to fix)"; $issues++ }
    else                      { UI-Ok "ExecutionPolicy: $policy" }

    foreach ($manager in $script:PKG_MANAGERS) {
        if (Pkg-Detect $manager) { UI-Ok "${manager}: detected" }
    }

    if (Reboot-Pending) { UI-Warn 'reboot pending from a previous operation' }

    if ($script:ArgsGlobal.Dev) {
        foreach ($manager in $script:PKG_DEV) {
            if (Pkg-Detect $manager) { UI-Ok "$manager (dev): detected" }
        }
    }

    UI-Rule
    if ($issues -eq 0) {
        UI-Ok 'all clear'
        return 0
    }
    UI-Warn "$issues issue(s) found"
    return 1
}
