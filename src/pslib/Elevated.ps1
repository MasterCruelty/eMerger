# Elevation for the admin managers only. The caller stays unelevated and
# keeps config.ps1, the profile and the hooks. One elevated child runs the
# admin managers and loads none of those: settings reach it as validated
# arguments, never as code. Results come back through a file the child
# creates, the caller replays them on its own console.

# Flags of the caller the child may receive, all plain switches.
$script:ELEVATED_FLAGS = @('-v', '-y', '--security', '--ascii', '--accept-licenses')

# Return the folders that only administrators can write: Windows, System32,
# Program Files (both). Windows takes them from the API, never from variables
# a user can override; elsewhere (tests) from the variables.
function _Elevated-Admin-Roots {
    if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        $roots = @([Environment]::GetFolderPath('Windows'), [Environment]::GetFolderPath('System'),
                   [Environment]::GetFolderPath('ProgramFiles'), [Environment]::GetFolderPath('ProgramFilesX86'))
    } else {
        $roots = @("$env:SystemRoot", [IO.Path]::Combine("$env:SystemRoot", 'System32'), "$env:ProgramFiles")
    }
    return @($roots | Where-Object { $_ -and [IO.Path]::IsPathRooted($_) })
}

# Return the machine-scope value of environment variable $Name, or $null.
# Only Windows has a machine scope; elsewhere nothing is trusted.
function _Elevated-Machine-Env {
    param([string]$Name)
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { return $null }
    return [Environment]::GetEnvironmentVariable($Name, 'Machine')
}

# Variables that make the .NET runtime, the CLR profiler API or PowerShell
# load or trust attacker code, cleared in the elevated child by name or prefix.
$script:ELEVATED_CLEAR_NAMES = @('PSExecutionPolicyPreference', 'PSModuleAnalysisCachePath', '__PSLockdownPolicy', 'ChocolateyToolsLocation')
$script:ELEVATED_CLEAR_PREFIXES = @('DOTNET_', 'COR_', 'CORECLR_', 'COMPlus_')

# Narrow the environment of the elevated child so nothing a user can set
# changes what runs as administrator: PATH and PSModulePath cut to system
# locations, ComSpec and PATHEXT reset, ChocolateyInstall taken from the
# machine scope, and the runtime hook variables (DOTNET_STARTUP_HOOKS, COR_*,
# CORECLR_*, COMPlus_*, PSExecutionPolicyPreference) removed for the managers
# it starts. They have already acted on this PowerShell process itself.
function Elevated-Restrict-Env {
    $sep = [IO.Path]::PathSeparator
    if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
        $windows = [Environment]::GetFolderPath('Windows'); $system = [Environment]::GetFolderPath('System')
        $data = [Environment]::GetFolderPath('CommonApplicationData'); $programs = [Environment]::GetFolderPath('ProgramFiles')
    } else {
        $windows = "$env:SystemRoot"; $system = [IO.Path]::Combine($windows, 'System32')
        $data = "$env:ProgramData"; $programs = "$env:ProgramFiles"
    }
    $shell = [IO.Path]::Combine($system, 'WindowsPowerShell', 'v1.0')
    $paths = @($system, $windows, [IO.Path]::Combine($system, 'Wbem'), $shell, [IO.Path]::Combine($data, 'chocolatey', 'bin'))
    $modules = @((Join-Path $PSHOME 'Modules'), [IO.Path]::Combine($programs, 'WindowsPowerShell', 'Modules'), [IO.Path]::Combine($shell, 'Modules'))
    $env:PATH = ($paths | Where-Object { [IO.Path]::IsPathRooted($_) }) -join $sep
    $env:PSModulePath = ($modules | Where-Object { [IO.Path]::IsPathRooted($_) }) -join $sep
    foreach ($entry in @(Get-ChildItem env:)) {
        $name = $entry.Name
        $isPrefixed = @($script:ELEVATED_CLEAR_PREFIXES | Where-Object { $name.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0
        if ($isPrefixed -or ($script:ELEVATED_CLEAR_NAMES -contains $name)) { Remove-Item -LiteralPath "env:$name" -ErrorAction SilentlyContinue }
    }
    $env:ComSpec = [IO.Path]::Combine($system, 'cmd.exe')
    $env:PATHEXT = '.COM;.EXE;.BAT;.CMD'
    $choco = _Elevated-Machine-Env 'ChocolateyInstall'
    if ($choco -and [IO.Path]::IsPathRooted($choco)) { $env:ChocolateyInstall = $choco } else { Remove-Item -LiteralPath 'env:ChocolateyInstall' -ErrorAction SilentlyContinue }
}

# Return $true when a standard user can write to, or has taken ownership of,
# $Path or an ancestor up to the ProgramData chocolatey folder: an ACL entry
# for Users, Authenticated Users or Everyone with a write right, or an owner
# other than Administrators, SYSTEM and TrustedInstaller. An unreadable ACL
# counts as writable. Always $false off Windows, where there is no ACL.
function _Elevated-Users-Can-Write {
    param([string]$Path)
    if ([Environment]::OSVersion.Platform -ne [PlatformID]::Win32NT) { return $false }
    $writeMask = 0x000D0046
    $everyone = @('S-1-1-0', 'S-1-5-11', 'S-1-5-32-545')
    $owners = @('S-1-5-32-544', 'S-1-5-18', 'S-1-5-80-956008885-3418522649-1831038044-1853292631-2271478464')
    try {
        $stop = [IO.Path]::Combine([Environment]::GetFolderPath('CommonApplicationData'), 'chocolatey').TrimEnd('\')
        $dir = $Path
        while ($dir) {
            $acl = Get-Acl -LiteralPath $dir -ErrorAction Stop
            $ownerSid = $acl.GetOwner([Security.Principal.SecurityIdentifier]).Value
            if ($owners -notcontains $ownerSid) { return $true }
            foreach ($rule in $acl.GetAccessRules($true, $true, [Security.Principal.SecurityIdentifier])) {
                if ($rule.AccessControlType -eq 'Allow' -and ($everyone -contains $rule.IdentityReference.Value) -and (([int]$rule.FileSystemRights -band $writeMask) -ne 0)) { return $true }
            }
            if ($dir.TrimEnd('\') -ieq $stop) { break }
            $dir = Split-Path -Parent $dir
        }
        return $false
    } catch { return $true }
}

# Return a refusal message when the executable of admin manager $Manager,
# found on the child's PATH, is outside the locations only administrators can
# write (Windows, System32, Program Files, or ProgramData\chocolatey while
# its ACL denies standard users), else an empty string. A manager with no
# executable on PATH is not refused here: it is simply not found.
function Elevated-Exe-Refusal {
    param([string]$Manager)
    $exe = switch ($Manager) { 'choco' { 'choco' } 'wsl' { 'wsl' } default { '' } }
    if (-not $exe) { return '' }
    $app = Get-Command $exe -CommandType Application -ErrorAction SilentlyContinue | Select-Object -First 1
    if (-not $app) { return '' }
    $path = $app.Source
    if (-not $path) { $path = $app.Path }
    $full = [IO.Path]::GetFullPath($path)
    $sep = [string][IO.Path]::DirectorySeparatorChar
    $inside = { param($Root) $Root -and $full.StartsWith($Root.TrimEnd('\', '/') + $sep, [StringComparison]::OrdinalIgnoreCase) }
    foreach ($root in (_Elevated-Admin-Roots)) {
        if (& $inside $root) { return '' }
    }
    $choco = [IO.Path]::Combine($(if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) { [Environment]::GetFolderPath('CommonApplicationData') } else { "$env:ProgramData" }), 'chocolatey')
    if ($Manager -eq 'choco' -and (& $inside $choco) -and -not (_Elevated-Users-Can-Write (Split-Path -Parent $full))) { return '' }
    return "$exe is outside the administrator-only locations ($full), not run elevated"
}

# Build the child's arguments after the script path: the result file, the
# managers, the numeric settings, then the switches that change how the
# admin managers run.
function Elevated-Args {
    param([string]$ResultFile, [string[]]$Managers)
    $out = @('--elevated-child', $ResultFile, ($Managers -join ','),
             [string][int]$script:RETRY_ATTEMPTS, [string][int]$script:RETRY_DELAY,
             [string][int]$script:MANAGER_TIMEOUT, [string][int]$script:QUIET_LEVEL)
    if ($script:UI_VERBOSE)          { $out += '-v' }
    if ($script:ArgsGlobal.Yes)      { $out += '-y' }
    if ($script:ArgsGlobal.Security) { $out += '--security' }
    if ($script:ArgsGlobal.Ascii)  { $out += '--ascii' }
    if ($script:ArgsGlobal.AcceptLicenses) { $out += '--accept-licenses' }
    return ,$out
}

# Return the failed result of manager $Name the child did not report on,
# with $Why as its only output line.
function _Elevated-Missing-Result {
    param([string]$Name, [string]$Why)
    return [pscustomobject]@{
        name = $Name; result = 'fail'; secs = 0; changed = 0
        steps = @([pscustomobject]@{ label = $Name; ok = $false; rc = '1'; stat = ''; tail = @($Why) })
    }
}

# Run $ScriptPath under the current PowerShell host with a UAC prompt, wait,
# and return its exit code. Throws when the prompt is declined.
function Elevated-Start {
    param([string]$ScriptPath, [string[]]$Arguments)
    $words = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $ScriptPath) + @($Arguments)
    $commandLine = ($words | ForEach-Object { Run-Quote $_ }) -join ' '
    $process = Start-Process -FilePath (Run-PowerShell-Path) -ArgumentList $commandLine -Verb RunAs -Wait -PassThru
    return [int]$process.ExitCode
}

# Run $Managers in one elevated child (one UAC prompt) and wait. Return a
# hashtable name -> result (result, secs, changed, steps). A declined
# prompt, a crash or a missing result file fails every manager it covers.
function Elevated-Run {
    param([string[]]$Managers)
    $file = Join-Path ([IO.Path]::GetTempPath()) ("emerger-" + [guid]::NewGuid().ToString('N') + '.json')
    $results = @{}
    $why = ''
    $rc = $null
    try {
        $rc = Elevated-Start (Join-Path $script:EMERGER_SRC 'emerger.ps1') (Elevated-Args $file $Managers)
    } catch {
        $why = "elevation failed: $($_.Exception.Message)"
    }
    # Child writes with CreateNew and exits 0 or 3 only after that write
    # succeeded: any other code means the file, if any, is not its own.
    if (-not $why -and @(0, 3) -notcontains $rc) {
        $why = "elevated child exited with rc=$rc and wrote no result"
    }
    if (-not $why) {
        try {
            $payload = Get-Content -LiteralPath $file -Raw -ErrorAction Stop | ConvertFrom-Json
            foreach ($entry in @($payload.managers)) {
                if ($Managers -contains $entry.name) { $results[[string]$entry.name] = $entry }
            }
            foreach ($line in @($payload.log)) { if ($line -is [string]) { Log-Append-Raw $line } }
        } catch {
            $why = "elevated child exited with rc=$rc and wrote no result"
        }
    }
    Remove-Item -LiteralPath $file -Force -ErrorAction SilentlyContinue
    if ($why) {
        UI-Warn $why
        Log-Error $why
    }
    foreach ($manager in $Managers) {
        if (-not $results.ContainsKey($manager)) {
            if (-not $why) { $why = "elevated child exited with rc=$rc without a result for $manager" }
            $results[$manager] = _Elevated-Missing-Result $manager $why
        }
    }
    return $results
}

# Print elevated result $Result of manager $Name the way an in-process run
# prints it.
function Elevated-Show {
    param([string]$Name, $Result)
    UI-Section (Pkg-Icon $Name) $Name (Estimate-Read $Name)
    foreach ($step in @($Result.steps)) {
        if ($step.ok) { UI-Done ([string]$step.label) ([string]$step.stat); continue }
        UI-Fail ([string]$step.label) ([string]$step.rc)
        $tail = @($step.tail | ForEach-Object { [string]$_ })
        if ($tail.Count -gt 0) { UI-Fail-Tail $tail }
    }
    # Child prints its own hint on its console, it is not replayed.
    if ($Name -eq 'PSWindowsUpdate' -and -not $script:ArgsGlobal.AcceptLicenses) {
        UI-Muted 'updates not installed: they may need licence agreement, run with --accept-licenses'
    }
    $script:PKG_CHANGED += [int]$Result.changed
}

# Write $Text to a file that must not exist yet (CreateNew), so the elevated
# child never writes through a link planted at that path.
function _Elevated-Write-New {
    param([string]$Path, [string]$Text)
    $stream = [IO.File]::Open($Path, [IO.FileMode]::CreateNew, [IO.FileAccess]::Write, [IO.FileShare]::None)
    try {
        $bytes = (New-Object System.Text.UTF8Encoding $false).GetBytes($Text)
        $stream.Write($bytes, 0, $bytes.Length)
    } finally { $stream.Dispose() }
}

# Return $true when $Path is a result file Elevated-Run would name: a rooted
# path on a local disk (no UNC or device path) whose leaf is emerger-<32 hex>.json.
function _Elevated-Is-Result-Path {
    param([string]$Path)
    if (-not [IO.Path]::IsPathRooted($Path)) { return $false }
    if ($Path -match '^[\\/]{2}') { return $false }
    return ((Split-Path -Leaf $Path) -cmatch '^emerger-[0-9a-f]{32}\.json$')
}

# Child side: validate $Argv (as built by Elevated-Args), hold the elevated
# lock, run the managers, write the result file. Return 0 when all
# succeeded, 3 on a failure, 2 on invalid arguments, 1 when another elevated
# child holds the lock or the result cannot be written.
function Elevated-Child {
    param([string[]]$Argv)
    $script:QUIET_LEVEL = 0
    $script:ArgsGlobal = Args-Parse @()
    if ($Argv.Count -lt 7) { [Console]::Error.WriteLine('elevated child: missing arguments'); return 2 }
    $file = [string]$Argv[1]
    $managers = @(([string]$Argv[2]) -split ',' | Where-Object { $_ })
    $numbers = @($Argv[3..6] | ForEach-Object { [string]$_ })
    $flags = @(if ($Argv.Count -gt 7) { $Argv[7..($Argv.Count - 1)] })
    $invalid = @($managers | Where-Object { -not (Pkg-Need-Admin $_) }) +
           @($numbers | Where-Object { $_ -notmatch '^\d{1,9}$' }) +
           @($flags | Where-Object { $script:ELEVATED_FLAGS -notcontains $_ })
    if (-not (_Elevated-Is-Result-Path $file) -or $managers.Count -eq 0 -or $invalid.Count -gt 0) {
        [Console]::Error.WriteLine("elevated child: invalid arguments: $($invalid -join ' ')")
        return 2
    }
    $script:RETRY_ATTEMPTS = [int]$numbers[0]; $script:RETRY_DELAY = [int]$numbers[1]
    $script:MANAGER_TIMEOUT = [int]$numbers[2]
    $script:ArgsGlobal = Args-Parse $flags -Into $script:ArgsGlobal
    $script:QUIET_LEVEL = [int]$numbers[3]
    UI-Init
    # No log file: the caller writes these lines to its own log.
    $script:LOG_BUFFER = New-Object System.Collections.Generic.List[string]
    # Caller's run lock dies with an interrupted caller, this one lives
    # as long as the managers run. Without a lock the child does not run:
    # the state directory of the account it runs under is created for it.
    $lock = $null
    try {
        [void][IO.Directory]::CreateDirectory($script:EMERGER_STATE)
        $lock = Lock-Open (Lock-Elevated-Path)
    } catch {
        [Console]::Error.WriteLine("elevated child: cannot take the elevated lock: $($_.Exception.Message)")
        return 1
    }
    if ($null -eq $lock) {
        [Console]::Error.WriteLine('elevated child: another elevated run is in progress')
        return 1
    }
    try {
        return (_Elevated-Child-Run $file $managers)
    } finally {
        Lock-Release $lock
    }
}

# Run $Managers in the child and write their results to $File. Return 0, 3
# when a manager failed, or 1 when the result cannot be written.
function _Elevated-Child-Run {
    param([string]$File, [string[]]$Managers)
    $out = @()
    $failCount = 0
    foreach ($manager in $Managers) {
        $script:RUN_STEPS = New-Object System.Collections.Generic.List[object]
        $before = $script:PKG_CHANGED
        $started = [DateTime]::UtcNow
        $refusal = Elevated-Exe-Refusal $manager
        if ($refusal) {
            Log-Error $refusal
            $script:RUN_STEPS.Add([pscustomobject]@{ label = $manager; ok = $false; rc = '1'; stat = ''; tail = @($refusal) })
            $isOk = $false
        } else {
            $isOk = Pkg-Run $manager
        }
        if (-not $isOk) { $failCount++ }
        $out += [pscustomobject]@{
            name = $manager; result = $(if ($isOk) { 'ok' } else { 'fail' })
            secs = Sys-Elapsed-Seconds $started
            changed = [int]($script:PKG_CHANGED - $before)
            steps = $script:RUN_STEPS.ToArray()
        }
    }
    $script:RUN_STEPS = $null
    $json = [pscustomobject]@{ managers = $out; log = $script:LOG_BUFFER.ToArray() } | ConvertTo-Json -Depth 6 -Compress
    try { _Elevated-Write-New $file $json } catch {
        [Console]::Error.WriteLine("elevated child: cannot write ${file}: $($_.Exception.Message)")
        return 1
    }
    if ($failCount -gt 0) { return 3 }
    return 0
}
