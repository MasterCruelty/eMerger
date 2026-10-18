# Platform helpers.

# Return $true when $Command resolves to a command.
function Sys-Has {
    param([string]$Command)
    return [bool](Get-Command $Command -ErrorAction SilentlyContinue)
}

# Return the Windows edition and release, such as "Windows 11 Pro 23H2", read
# from the registry because CIM is slow.
function Sys-OS {
    try {
        $currentVersion = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction Stop
        $name = [string]$currentVersion.ProductName
        # ProductName still says "Windows 10" on Windows 11 (build 22000+).
        if ([int]$currentVersion.CurrentBuild -ge 22000) { $name = $name -replace 'Windows 10', 'Windows 11' }
        if ($currentVersion.DisplayVersion) { $name += " $($currentVersion.DisplayVersion)" }
        if ($name.Trim()) { return $name.Trim() }
    } catch {}
    try { return [Runtime.InteropServices.RuntimeInformation]::OSDescription.Trim() } catch {}
    $os = [Environment]::OSVersion
    "Windows $($os.Version)"
}

# Return the processor architecture, '' when unknown.
function Sys-Architecture {
    if ($env:PROCESSOR_ARCHITECTURE) { return $env:PROCESSOR_ARCHITECTURE }
    try { return [string][Runtime.InteropServices.RuntimeInformation]::OSArchitecture } catch {}
    return ''
}

# Return $true when the process runs as Administrator, $false off Windows.
function Sys-IsAdmin {
    try {
        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = [Security.Principal.WindowsPrincipal]::new($identity)
        return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

# Normalise numeric knob $Name (a script variable) to a whole number, or set
# it to $Default with a warning when it holds anything else. Empty means the
# default. Values past 999999999 are capped there, so every [int] cast holds.
function Sys-Knob-Int {
    param([string]$Name, [int]$Default)
    $value = "$(Get-Variable -Name $Name -Scope Script -ValueOnly -ErrorAction SilentlyContinue)"
    if ($value -match '^[0-9]{1,15}$') {
        Set-Variable -Name $Name -Scope Script -Value ([int][math]::Min([int64]$value, 999999999))
        return
    }
    if ($value) { UI-Warn "$Name=`"$value`" is not a whole number, using $Default" }
    Set-Variable -Name $Name -Scope Script -Value $Default
}

# Return the whole seconds from $From to $To (default now), truncated.
function Sys-Elapsed-Seconds {
    param([DateTime]$From, [DateTime]$To = [DateTime]::UtcNow)
    return [int][math]::Floor(($To - $From).TotalSeconds)
}

# Fetch the one-line weather report from wttr.in (3 s timeout), sanitized,
# newlines joined with spaces. Return '' on any failure.
function Sys-Fetch-Weather {
    try {
        $response = Invoke-WebRequest -Uri 'https://wttr.in/?format=%l:+%c+%t+%w+%m' -TimeoutSec 3 -UseBasicParsing
        return ((UI-Sanitize ([string]$response.Content)) -replace '\s*\n\s*', ' ').Trim()
    } catch { return '' }
}
