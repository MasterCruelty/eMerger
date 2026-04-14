#Requires -Version 5.1
[CmdletBinding()]
param(
    [Parameter(ValueFromRemainingArguments = $true)]
    [string[]]$Arguments
)

$ErrorActionPreference = 'Stop'

# Paths.
$script:EMERGER_SRC     = $PSScriptRoot
$script:EMERGER_ROOT    = Split-Path -Parent $script:EMERGER_SRC
$script:EMERGER_LIB     = Join-Path $script:EMERGER_SRC 'pslib'
$versionFile = Join-Path $script:EMERGER_ROOT 'VERSION'
$script:EMERGER_VERSION = if (Test-Path $versionFile) { (Get-Content $versionFile -Raw).Trim() } else { '0.0.0' }

$script:EMERGER_CONFIG = Join-Path $env:APPDATA       'emerger'
$script:EMERGER_CACHE  = Join-Path $env:LOCALAPPDATA  'emerger\cache'
$script:EMERGER_STATE  = Join-Path $env:LOCALAPPDATA  'emerger\state'
foreach ($d in @($script:EMERGER_CONFIG, $script:EMERGER_CACHE, $script:EMERGER_STATE)) {
    if (-not (Test-Path $d)) { New-Item -ItemType Directory -Path $d -Force | Out-Null }
}

# Load libs.
. (Join-Path $script:EMERGER_LIB 'UI.ps1')
. (Join-Path $script:EMERGER_LIB 'Log.ps1')
. (Join-Path $script:EMERGER_LIB 'Sys.ps1')
. (Join-Path $script:EMERGER_LIB 'Args.ps1')
. (Join-Path $script:EMERGER_LIB 'Packages.ps1')
. (Join-Path $script:EMERGER_LIB 'Clean.ps1')
. (Join-Path $script:EMERGER_LIB 'Hooks.ps1')
. (Join-Path $script:EMERGER_LIB 'Update.ps1')
. (Join-Path $script:EMERGER_LIB 'Notify.ps1')
. (Join-Path $script:EMERGER_LIB 'Summary.ps1')
. (Join-Path $script:EMERGER_LIB 'Doctor.ps1')
. (Join-Path $script:EMERGER_LIB 'Profiles.ps1')

# User config.
$userCfg = Join-Path $script:EMERGER_CONFIG 'config.ps1'
if (Test-Path $userCfg) { . $userCfg }

# Profile prescan (profile sets defaults, CLI wins).
$profileName = Args-Prescan-Profile $Arguments
if ($profileName) { Load-Profile $profileName }

# Parse CLI flags.
$script:ArgsGlobal = Parse-Args $Arguments
$script:Summary    = New-Object System.Collections.Generic.List[PSCustomObject]

Log-Init

# Subcommand-style short-circuits.
if ($script:ArgsGlobal.Help)    { Get-Content (Join-Path $script:EMERGER_LIB 'Help.txt') ; exit 0 }
if ($script:ArgsGlobal.Version) { Write-Host "eMerger $script:EMERGER_VERSION"; exit 0 }
if ($script:ArgsGlobal.Errors)  { Show-Errors; exit 0 }
if ($script:ArgsGlobal.History) { Show-History; exit 0 }
if ($script:ArgsGlobal.Doctor)  { $rc = Doctor-Run; exit $rc }
if ($script:ArgsGlobal.SelfUpdate) { $rc = Self-Update $script:EMERGER_ROOT; exit $rc }
if ($script:ArgsGlobal.AutoUpdate) { $rc = Setup-Task  $script:EMERGER_ROOT; exit $rc }
if ($script:ArgsGlobal.ListProfiles) { List-Profiles; exit 0 }
if ($script:ArgsGlobal.Metrics) {
    $hist = Join-Path $script:EMERGER_STATE 'history.jsonl'
    if (-not (Test-Path $hist)) { UI-Err 'No history yet'; exit 1 }
    $last = Get-Content $hist -Tail 1 | ConvertFrom-Json
    $epoch = [int64](([DateTime]$last.ts).ToUniversalTime() - [DateTime]'1970-01-01').TotalSeconds
    $tmp = "$($script:ArgsGlobal.Metrics).tmp"
    $out = @()
    $out += "# HELP emerger_last_run_timestamp_seconds Unix timestamp of the last eMerger run"
    $out += "# TYPE emerger_last_run_timestamp_seconds gauge"
    $out += "emerger_last_run_timestamp_seconds $epoch"
    $out += "# HELP emerger_last_run_duration_seconds Duration of the last run"
    $out += "# TYPE emerger_last_run_duration_seconds gauge"
    $out += "emerger_last_run_duration_seconds $($last.duration)"
    $out += "# HELP emerger_last_run_errors Manager failures in the last run"
    $out += "# TYPE emerger_last_run_errors gauge"
    $out += "emerger_last_run_errors $($last.errors)"
    $out += "# HELP emerger_reboot_required Whether a reboot is pending (0/1)"
    $out += "# TYPE emerger_reboot_required gauge"
    $out += "emerger_reboot_required $($last.reboot)"
    $out += "# HELP emerger_manager_ok Per-manager success (1=ok,0=fail)"
    $out += "# TYPE emerger_manager_ok gauge"
    foreach ($m in $last.managers) {
        $v = if ($m.result -eq 'ok') { 1 } else { 0 }
        $out += "emerger_manager_ok{manager=`"$($m.name)`"} $v"
    }
    $out | Set-Content -Path $tmp
    Move-Item -Force $tmp $script:ArgsGlobal.Metrics
    UI-Ok "metrics written to $($script:ArgsGlobal.Metrics)"
    exit 0
}
if ($script:ArgsGlobal.RebuildCache) {
    Remove-Item $script:EMERGER_CACHE -Recurse -Force -ErrorAction SilentlyContinue
    New-Item -ItemType Directory -Path $script:EMERGER_CACHE -Force | Out-Null
    UI-Ok 'Detection cache cleared'
}
if ($script:ArgsGlobal.Reboot) {
    if (Reboot-Pending) {
        UI-Warn 'Rebooting now.'
        Restart-Computer -Force
        exit 0
    } else { UI-Ok 'No reboot needed.'; exit 0 }
}

# Elevation: relaunch elevated if any detected manager needs it.
if (Pkg-Need-Admin-Any -IncludeDev:$script:ArgsGlobal.Dev) {
    if (-not (Sys-IsAdmin) -and -not $script:ArgsGlobal.DryRun) {
        UI-Warn 'Admin privileges required by one of the detected managers. Relaunching elevated…'
        Log-Info 'relaunching elevated'
        Sys-Start-Elevated (Join-Path $script:EMERGER_SRC 'emerger.ps1') $Arguments
        exit 0
    }
}

# Battery check.
if (Sys-On-Battery) {
    $pct = Sys-Battery-Percent
    if ($pct -lt 20 -and -not $script:ArgsGlobal.Yes) {
        UI-Warn "On battery at ${pct}%. Updates are I/O heavy."
        $a = Read-Host '    Continue anyway? [y/N]'
        if ($a -notmatch '^[Yy]') { UI-Muted 'Aborted.'; exit 0 }
    }
}

# Main flow.
$start = [DateTime]::UtcNow

if ($script:ArgsGlobal.Json) {
    $script:ArgsGlobal.NoLogo = $true; $script:ArgsGlobal.NoInfo = $true; $script:QUIET_LEVEL = 3
}
if (-not $script:ArgsGlobal.NoLogo -and $script:QUIET_LEVEL -lt 1) {
    UI-Logo (Join-Path $script:EMERGER_SRC 'logo\logo.txt')
}
if ($script:QUIET_LEVEL -lt 2) {
    if (-not $script:ArgsGlobal.NoInfo) {
        UI-Muted ("{0}  $(UI-Glyph dot)  {1}  $(UI-Glyph dot)  {2}" -f (Sys-OS), (Sys-Arch), (Get-Date -Format 'yyyy-MM-dd HH:mm'))
    }
    UI-Muted ("eMerger v$script:EMERGER_VERSION  $(UI-Glyph dot)  github.com/MasterCruelty/eMerger")
}

Hooks-Run 'pre'

$detected = Pkg-Detect-All -IncludeDev:$script:ArgsGlobal.Dev
$total = $detected.Count
if ($total -eq 0) { UI-Warn 'No supported package managers detected.' }

$onlyList   = @(); if ($script:ArgsGlobal.Only)   { $onlyList   = $script:ArgsGlobal.Only -split ',' | ForEach-Object { $_.Trim() } }
$exceptList = @(); if ($script:ArgsGlobal.Except) { $exceptList = $script:ArgsGlobal.Except -split ',' | ForEach-Object { $_.Trim() } }

$filtered = @()
foreach ($m in $detected) {
    if ($onlyList.Count   -gt 0 -and ($onlyList -notcontains $m))   { continue }
    if ($exceptList.Count -gt 0 -and ($exceptList -contains $m))    { UI-Muted "skip $m (--except)"; continue }
    $filtered += $m
}
$detected = $filtered
$total = $detected.Count

$i = 0
foreach ($m in $detected) {
    $i++
    UI-Step $i $total $m
    $ok = Pkg-Run $m
    $script:Summary.Add([pscustomobject]@{ Name = $m; Result = $(if ($ok) { 'ok' } else { 'fail' }) })
}

if (-not $script:ArgsGlobal.NoCache) { Clean-Temp }
if (-not $script:ArgsGlobal.NoTrash) { Clean-RecycleBin }

Hooks-Run 'post'

$duration = [int]([DateTime]::UtcNow - $start).TotalSeconds
Summary-Print $duration
Notify-Send-Result

$errors = @($script:Summary | Where-Object { $_.Result -eq 'fail' }).Count
if ($errors -gt 0) { exit 3 }
if ($script:ArgsGlobal.RebootExit -and (Reboot-Pending)) { exit 4 }
exit 0
