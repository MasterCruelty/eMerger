# Per-user run lock, and the lock the elevated child holds.

# Return the path of the per-user run lock. It lives in the user's own state directory,
# so a scheduled task in session 0 and an interactive run of the same user
# share it, and no other account can create it first.
function Lock-Path {
    return (Join-Path $script:EMERGER_STATE 'run.lock')
}

# Return the path of the lock the elevated child holds while its managers
# run, so an interrupted caller's child still blocks the next run.
function Lock-Elevated-Path {
    return (Join-Path $script:EMERGER_STATE 'elevated.lock')
}

# Open lock file $Path for exclusive use, creating it when missing. Return
# the open stream, or $null when another process holds it. Any other failure
# (missing directory, access denied) throws.
function Lock-Open {
    param([string]$Path)
    try {
        return [IO.File]::Open($Path, [IO.FileMode]::OpenOrCreate, [IO.FileAccess]::ReadWrite, [IO.FileShare]::None)
    } catch {
        # Busy: Windows reports ERROR_SHARING_VIOLATION or ERROR_LOCK_VIOLATION
        # (0x80070020, 0x80070021), Unix the flock's EWOULDBLOCK (11, 35 on macOS).
        $cause = $_.Exception.GetBaseException()
        if ($cause -is [IO.IOException]) {
            if (@(11, 35, -2147024864, -2147024863) -contains $cause.HResult) { return $null }
        }
        throw
    }
}

# Take the per-user run lock without waiting. Return the held lock, or $null
# when another run holds it or an elevated child of an earlier run is still
# working. The OS releases it when the process dies.
function Lock-Acquire {
    $lock = Lock-Open (Lock-Path)
    if (-not $lock) { return $null }
    try { $child = Lock-Open (Lock-Elevated-Path) } catch { $lock.Dispose(); throw }
    if (-not $child) { $lock.Dispose(); return $null }
    $child.Dispose()
    return $lock
}

# Release a lock returned by Lock-Acquire or Lock-Open ($null is a
# no-op). The file stays: deleting it would race with the next run's open.
function Lock-Release {
    param($Lock)
    if (-not $Lock) { return }
    $Lock.Dispose()
}
