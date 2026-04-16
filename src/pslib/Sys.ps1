# Platform helpers.

function Sys-Has {
    param([string]$Cmd)
    return [bool](Get-Command $Cmd -ErrorAction SilentlyContinue)
}

function Sys-OS {
    $os = [Environment]::OSVersion
    "Windows $($os.Version)"
}

function Sys-Arch { return $env:PROCESSOR_ARCHITECTURE }

function Sys-IsAdmin {
    try {
        $id = [Security.Principal.WindowsIdentity]::GetCurrent()
        $p = [Security.Principal.WindowsPrincipal]::new($id)
        return $p.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
    } catch {
        return $false
    }
}

function Sys-Start-Elevated {
    param([string]$ScriptPath, [string[]]$Arguments)
    $argStr = ($Arguments | ForEach-Object { if ($_ -match '\s') { '"' + $_ + '"' } else { $_ } }) -join ' '
    Start-Process -FilePath 'powershell' `
        -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$ScriptPath`"", $argStr `
        -Verb RunAs -Wait
}

function Sys-On-Battery {
    try {
        $b = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
        if ($b -and $b.BatteryStatus -eq 1) { return $true }
    } catch {}
    return $false
}

function Sys-Battery-Percent {
    try {
        $b = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
        if ($b) { return [int]$b.EstimatedChargeRemaining }
    } catch {}
    return 100
}

function Sys-Disk-Free-GB {
    param([string]$Drive = 'C')
    try {
        $d = Get-PSDrive $Drive -ErrorAction Stop
        return [math]::Round($d.Free / 1GB, 1)
    } catch { return 0 }
}
