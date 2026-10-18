# Pending reboot detection and the reboot advisory.

# Return $true when any registry key Windows sets for a pending reboot exists.
function Reboot-Pending {
    # Several signals can indicate a pending reboot on Windows.
    $keys = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending',
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired',
        'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations'
    )
    foreach ($key in $keys) {
        if (Test-Path $key) { return $true }
    }
    return $false
}

# Print the reboot advice when a reboot is pending.
function Reboot-Advisory {
    if (Reboot-Pending) {
        Write-Host ("`n  " + (UI-Color 'bold yellow' "$(UI-Glyph warn) Reboot recommended") + '  ' + (UI-Color 'dim gray' '(pending updates require restart)'))
        Write-Host ("    " + (UI-Color 'dim gray' 'run:') + ' Restart-Computer')
    }
}
