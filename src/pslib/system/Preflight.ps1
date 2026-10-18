# Checks before a run: battery and free disk space.

# Return $true when any battery reports BatteryStatus 1 (discharging).
function Preflight-Is-On-Battery {
    try {
        foreach ($battery in @(Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue)) {
            if ($battery.BatteryStatus -eq 1) { return $true }
        }
    } catch {}
    return $false
}

# Return the charge in percent, the floor of the average over every battery,
# or 100 when there is none or the query fails.
function Preflight-Battery-Percent {
    try {
        $batteries = @(Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue)
        if ($batteries.Count -gt 0) {
            return [int][math]::Floor(($batteries | Measure-Object -Property EstimatedChargeRemaining -Average).Average)
        }
    } catch {}
    return 100
}

# Return the free space of the system drive in whole MiB, -1 when unknown.
function Preflight-Disk-Free-MB {
    $drive = "$env:SystemDrive".TrimEnd(':')
    if (-not $drive) { $drive = 'C' }
    try {
        $psDrive = Get-PSDrive $drive -ErrorAction Stop
        return [int][math]::Floor($psDrive.Free / 1MB)
    } catch { return -1 }
}

# Ask before a run on battery below BATTERY_MIN_PCT, unless -y. Return $false
# when the answer is no.
function Preflight-Battery {
    if (Preflight-Is-On-Battery) {
        $percent = Preflight-Battery-Percent
        if ($percent -lt $script:BATTERY_MIN_PCT -and -not $script:ArgsGlobal.Yes) {
            UI-Warn "On battery at ${percent}%. Updates are I/O heavy."
            if (-not (UI-Confirm 'Continue anyway?' 'n' "(${percent}% battery)")) { UI-Muted 'Aborted.'; return $false }
        }
    }
    return $true
}

# Ask before a run with less than DISK_MIN_FREE_MB free on the system drive,
# unless -y. Return $false when the answer is no. An unknown free space passes.
function Preflight-Disk {
    $freeMb = Preflight-Disk-Free-MB
    if ($freeMb -ge 0 -and $freeMb -lt $script:DISK_MIN_FREE_MB) {
        UI-Warn "Low disk space on the system drive (${freeMb}MB free, threshold $($script:DISK_MIN_FREE_MB)MB)."
        if (-not $script:ArgsGlobal.Yes) {
            if (-not (UI-Confirm 'Continue anyway?' 'n')) { UI-Muted 'Aborted by user.'; return $false }
        }
    } elseif ($freeMb -ge 0) {
        Log-Info "disk precheck ok: ${freeMb}MB free"
    }
    return $true
}
