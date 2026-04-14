# Environment health check.

function Doctor-Run {
    UI-Title 'eMerger doctor (Windows)'
    $issues = 0

    UI-Ok "PowerShell $($PSVersionTable.PSVersion)"

    if (Sys-IsAdmin) { UI-Ok 'running as administrator' }
    else             { UI-Info 'not admin (elevation prompted when needed)' }

    $free = Sys-Disk-Free-GB 'C'
    if ($free -lt 2) { UI-Warn "low disk space on C: ($free GB)"; $issues++ }
    else             { UI-Ok  "disk: $free GB free on C:" }

    try {
        if (Test-Connection -ComputerName 'github.com' -Count 1 -Quiet -ErrorAction Stop) {
            UI-Ok 'network: github reachable'
        } else { UI-Warn 'network: github unreachable'; $issues++ }
    } catch { UI-Warn 'network: check failed'; $issues++ }

    $ep = Get-ExecutionPolicy -Scope CurrentUser
    if ($ep -eq 'Restricted') { UI-Warn "ExecutionPolicy=$ep (run setup.ps1 to fix)"; $issues++ }
    else                      { UI-Ok "ExecutionPolicy: $ep" }

    foreach ($m in $script:PKG_MANAGERS) {
        if (Pkg-Detect $m) { UI-Ok "$m: detected" }
    }

    if (Reboot-Pending) { UI-Warn 'reboot pending from a previous operation' }

    if ($script:ArgsGlobal.Dev) {
        foreach ($m in $script:PKG_DEV) {
            if (Pkg-Detect $m) { UI-Ok "$m (dev): detected" }
        }
    }

    UI-Hr
    if ($issues -eq 0) {
        UI-Ok 'all clear'
        return 0
    }
    UI-Warn "$issues issue(s) found"
    return 1
}
