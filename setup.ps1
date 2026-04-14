#Requires -Version 5.1
<#
.SYNOPSIS
  Install eMerger on Windows: register the `up` function, ensure execution
  policy allows it, scaffold %APPDATA%\emerger.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$REPO = Split-Path -Parent $PSCommandPath
. "$REPO\src\pslib\UI.ps1"
. "$REPO\src\pslib\Sys.ps1"

UI-Title 'eMerger setup (Windows)'

# ExecutionPolicy fix.
$ep = Get-ExecutionPolicy -Scope CurrentUser
if ($ep -eq 'Restricted' -or $ep -eq 'Undefined') {
    UI-Info "ExecutionPolicy is '$ep'; setting to RemoteSigned for CurrentUser."
    try {
        Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
        UI-Ok 'ExecutionPolicy updated.'
    } catch {
        UI-Warn "Could not change ExecutionPolicy: $($_.Exception.Message)"
    }
}

# PowerShell profile: add `up` function.
$profilePath = $PROFILE.CurrentUserAllHosts
$profileDir = Split-Path $profilePath
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Path $profilePath -Force | Out-Null }

$entry = "$REPO\src\emerger.ps1"
$existing = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
if ($existing -and $existing -match 'emerger\.ps1') {
    UI-Ok "'up' already registered in $profilePath"
} else {
    $block = @"

# eMerger (https://github.com/MasterCruelty/eMerger)
function up { & "$entry" @args }
"@
    Add-Content -Path $profilePath -Value $block
    UI-Ok "Added 'up' function to $profilePath"
}

# Config + hooks + profiles skeleton.
$cfg = Join-Path $env:APPDATA 'emerger'
@('hooks\pre.d','hooks\post.d','profiles.d') | ForEach-Object {
    $p = Join-Path $cfg $_
    if (-not (Test-Path $p)) { New-Item -ItemType Directory -Path $p -Force | Out-Null }
}

$configFile = Join-Path $cfg 'config.ps1'
if (-not (Test-Path $configFile)) {
    @'
# eMerger user config (Windows). Dot-sourced before argument parsing.
# Uncomment to set defaults.

# $script:ArgsGlobal.Dev      = $true
# $script:ArgsGlobal.NoTrash  = $true
# $script:ArgsGlobal.Security = $true
'@ | Set-Content $configFile -Encoding UTF8
    UI-Ok "Created $configFile"
}

UI-Info "Open a new PowerShell window (or: . `$PROFILE) and run: up --help"
