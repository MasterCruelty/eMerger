#Requires -Version 5.1
# No param block: an advanced script would bind -v, -V, -w and -err to
# the common parameters (-Verbose, -WarningAction...). Every word goes to $args.
# Profile function's @args hands `--only a,b` over as one array: join it
# back with commas, as the shell spelled it.
$Arguments = [string[]]@(foreach ($word in $args) { if ($word -is [array]) { @($word) -join ',' } else { $word } })

$ErrorActionPreference = 'Stop'

# Paths.
$script:EMERGER_SRC     = $PSScriptRoot
$script:EMERGER_ROOT    = Split-Path -Parent $script:EMERGER_SRC
$script:EMERGER_LIB     = Join-Path $script:EMERGER_SRC 'pslib'
$versionFile = Join-Path $script:EMERGER_ROOT 'VERSION'
$script:EMERGER_VERSION = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { '0.0.0' }

$script:EMERGER_CONFIG = Join-Path $env:APPDATA       'emerger'
$script:EMERGER_STATE  = Join-Path $env:LOCALAPPDATA  'emerger\state'
# Elevated child (see Elevated.ps1): admin managers only, it creates no
# directory and loads no config.ps1, profile or hook.
$script:IS_ELEVATED_CHILD = ($Arguments.Count -gt 0 -and $Arguments[0] -eq '--elevated-child')
if (-not $script:IS_ELEVATED_CHILD) {
    foreach ($dir in @($script:EMERGER_CONFIG, $script:EMERGER_STATE)) {
        if (-not (Test-Path -LiteralPath $dir)) { [void][IO.Directory]::CreateDirectory($dir) }
    }
}

# Load libs.
foreach ($lib in @('ui\Term', 'ui\Text', 'ui\Print', 'ui\Monitor', 'ui\Prompt', 'managers\Progress',
                   'Log', 'Sys', 'state\Lock', 'system\Preflight', 'Args', 'Run',
                   'managers\Packages', 'state\Estimate', 'state\Metrics', 'clean\Size',
                   'clean\Temp', 'clean\RecycleBin', 'Hooks', 'SelfUpdate', 'AutoUpdate',
                   'system\Notify', 'Summary', 'state\History', 'system\Reboot', 'Doctor',
                   'Profiles', 'Elevated')) {
    . (Join-Path $script:EMERGER_LIB "$lib.ps1")
}

if ($script:IS_ELEVATED_CHILD) {
    Elevated-Restrict-Env
    $script:RETRY_ATTEMPTS = 2; $script:RETRY_DELAY = 3; $script:MANAGER_TIMEOUT = 0
    exit (Elevated-Child $Arguments)
}

# Defaults first, config.ps1 and profiles write into it.
$script:ArgsGlobal = Args-Parse @()

# config.ps1 can change them.
$script:DISK_MIN_FREE_MB = 1024
$script:BATTERY_MIN_PCT  = 20
$script:RETRY_ATTEMPTS   = 2
$script:RETRY_DELAY      = 3
$script:MANAGER_TIMEOUT  = 0   # seconds per manager step, 0 = no limit

# User config.
$userConfig = Join-Path $script:EMERGER_CONFIG 'config.ps1'
if (Test-Path -LiteralPath $userConfig) { . $userConfig }

# Profile prescan (profile sets defaults, CLI wins).
$profileName = Args-Prescan-Profile $Arguments
if ($profileName) { Profiles-Load $profileName }

# Parse CLI flags.
$script:ArgsGlobal = Args-Parse $Arguments -Into $script:ArgsGlobal
$script:Summary    = New-Object System.Collections.Generic.List[PSCustomObject]
# --ascii changes the glyph table.
UI-Init

# Numeric knobs from config.ps1 or the profile, validated.
foreach ($knob in @(@('DISK_MIN_FREE_MB', 1024), @('BATTERY_MIN_PCT', 20), @('RETRY_ATTEMPTS', 2),
                    @('RETRY_DELAY', 3), @('MANAGER_TIMEOUT', 0))) {
    Sys-Knob-Int $knob[0] $knob[1]
}

Args-Warn-Unsupported

Log-Init

# Subcommand-style short-circuits.
if ($script:ArgsGlobal.Help)    { Get-Content (Join-Path $script:EMERGER_LIB 'Help.txt') ; exit 0 }
if ($script:ArgsGlobal.Version) { Write-Host "eMerger $script:EMERGER_VERSION"; exit 0 }
if ($script:ArgsGlobal.Errors)  { Log-Show-Errors; exit 0 }
if ($script:ArgsGlobal.History) { History-Show; exit 0 }
if ($script:ArgsGlobal.Changed) { UI-Warn '--changed is not supported on Windows, nothing to show.'; exit 0 }
if ($script:ArgsGlobal.Doctor)  { $rc = Doctor-Run; exit $rc }
if ($script:ArgsGlobal.ListProfiles) { Profiles-List; exit 0 }
if ($script:ArgsGlobal.Changelog) { UI-Warn '--changelog is not supported on Windows, nothing to show.'; exit 0 }
if ($script:ArgsGlobal.Rollback) { UI-Warn '--rollback is not supported on Windows, nothing to revert.'; exit 0 }
if ($script:ArgsGlobal.Metrics) { $rc = Metrics-Export $script:ArgsGlobal.Metrics; exit $rc }
# One run per user at a time, taken before
# anything that changes the system or eMerger's state. Released in finally,
# and by the OS if the process dies.
try { $script:RunLock = Lock-Acquire } catch {
    UI-Err "Cannot open the run lock $(Lock-Path): $($_.Exception.GetBaseException().Message)"
    exit 1
}
if (-not $script:RunLock) {
    UI-Err "Another eMerger run is in progress (lock: $(Lock-Path))."
    UI-Muted 'Wait for it to finish.'
    exit 1
}
# Set before every exit of the run below, so the finally block can tell an
# interrupted run from one that ended.
$script:HasRunEnded = $false
try {
    if ($script:ArgsGlobal.SelfUpdate) { $rc = SelfUpdate-Run $script:EMERGER_ROOT; $script:HasRunEnded = $true; exit $rc }
    if ($script:ArgsGlobal.AutoUpdate) { $rc = AutoUpdate-Register  $script:EMERGER_ROOT; $script:HasRunEnded = $true; exit $rc }
    if ($script:ArgsGlobal.RebuildCache) { UI-Muted 'Windows keeps no detection cache, nothing to clear.' }
    if ($script:ArgsGlobal.Reboot) {
        if (Reboot-Pending) {
            if ($script:ArgsGlobal.DryRun) { UI-Sub '[dry-run] would reboot'; $script:HasRunEnded = $true; exit 0 }
            UI-Warn 'Rebooting now.'
            Restart-Computer -Force
            $script:HasRunEnded = $true
            exit 0
        } else { UI-Ok 'No reboot needed.'; $script:HasRunEnded = $true; exit 0 }
    }

    if (-not (Preflight-Battery)) { $script:HasRunEnded = $true; exit 1 }
    if (-not (Preflight-Disk)) { $script:HasRunEnded = $true; exit 1 }

    # Main flow.
    $start = [DateTime]::UtcNow

    if ($script:ArgsGlobal.Json) {
        $script:ArgsGlobal.NoLogo = $true; $script:ArgsGlobal.NoInfo = $true; $script:QUIET_LEVEL = 3
    }
    if (-not $script:ArgsGlobal.NoLogo -and $script:QUIET_LEVEL -lt 1) {
        UI-Logo (Join-Path (Join-Path $script:EMERGER_SRC 'logo') 'logo.txt')
    }
    if ($script:QUIET_LEVEL -lt 2) {
        $versionText = UI-Color cyan "eMerger v$script:EMERGER_VERSION"
        if (-not $script:ArgsGlobal.NoInfo) {
            UI-Header @((UI-Color bold (Sys-OS)), (Sys-Architecture), (Get-Date -Format 'yyyy-MM-dd HH:mm'), $versionText)
        } else {
            UI-Header @($versionText)
        }
    }

    if ($script:ArgsGlobal.Weather -and $script:QUIET_LEVEL -lt 1) {
        $weather = Sys-Fetch-Weather
        if ($weather) { UI-Muted $weather }
    }

    Hooks-Run 'pre'

    $detected = Pkg-Detect-All -IncludeDev:$script:ArgsGlobal.Dev
    $total = $detected.Count
    if ($total -eq 0) { UI-Warn 'No supported package managers detected.' }

    $detected = Pkg-Select $detected
    $total = $detected.Count

    # Unelevated: the admin managers run in one elevated child (Elevated.ps1),
    # everything else, hooks included, stays in this process.
    $needsElevation = -not $script:ArgsGlobal.DryRun -and -not (Sys-IsAdmin)
    $adminManagers = @($detected | Where-Object { Pkg-Need-Admin $_ })
    $elevated = $null

    $step = 0
    foreach ($manager in $detected) {
        $step++
        UI-Step $step $total $manager
        if ($needsElevation -and (Pkg-Need-Admin $manager)) {
            if (-not $elevated) {
                UI-Warn "Admin privileges required by $($adminManagers -join ', '). Starting them elevated..."
                Log-Info "elevating: $($adminManagers -join ',')"
                $elevated = Elevated-Run $adminManagers
            }
            $result = $elevated[$manager]
            Elevated-Show $manager $result
            $script:Summary.Add([pscustomobject]@{ Name = $manager; Result = [string]$result.result; Secs = [int]$result.secs })
            continue
        }
        $started = [DateTime]::UtcNow
        $isOk = Pkg-Run $manager
        $seconds = Sys-Elapsed-Seconds $started
        $script:Summary.Add([pscustomobject]@{ Name = $manager; Result = $(if ($isOk) { 'ok' } else { 'fail' }); Secs = $seconds })
    }

    if (-not $script:ArgsGlobal.KeepCache) { Clean-Temp }
    if (-not $script:ArgsGlobal.KeepTrash) { Clean-RecycleBin }

    Hooks-Run 'post'

    $duration = Sys-Elapsed-Seconds $start
    Summary-Print $duration
    Notify-Send-Result

    $errors = Summary-Fail-Count
    $script:HasRunEnded = $true
    if ($errors -gt 0) { exit 3 }
    if ($script:ArgsGlobal.RebootExit -and (Reboot-Pending)) { exit 4 }
    exit 0
} catch {
    # Crashes keep their own error and exit code.
    $script:HasRunEnded = $true
    throw
} finally {
    Lock-Release $script:RunLock
    # Neither an exit nor an error: Ctrl-C stopped the script, whose finally
    # blocks still run. Without this exit, pwsh -File reports 0.
    if (-not $script:HasRunEnded) {
        try { UI-Err 'Interrupted (SIGINT), stopping.' } catch { [Console]::Error.WriteLine('Interrupted (SIGINT), stopping.') }
        try { Log-Warn 'interrupted by SIGINT' } catch {}
        exit 1
    }
}
