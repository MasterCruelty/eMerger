#Requires -Version 5.1
<#
.SYNOPSIS
  Install eMerger on Windows: register the `up` function, offer to allow
  scripts in the execution policy, scaffold %APPDATA%\emerger.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$REPO = Split-Path -Parent $PSCommandPath
. "$REPO\src\pslib\ui\Term.ps1"
. "$REPO\src\pslib\ui\Text.ps1"
. "$REPO\src\pslib\ui\Print.ps1"
. "$REPO\src\pslib\ui\Prompt.ps1"
. "$REPO\src\pslib\Sys.ps1"

UI-Title 'eMerger install (Windows)'

# ExecutionPolicy: changed only on an explicit yes (no answer means no).
$policy = Get-ExecutionPolicy -Scope CurrentUser
if ($policy -eq 'Restricted' -or $policy -eq 'Undefined') {
    UI-Info "ExecutionPolicy for CurrentUser is '$policy': the profile and 'up' may be blocked."
    if (UI-Confirm 'Set it to RemoteSigned for CurrentUser?' 'n') {
        try {
            Set-ExecutionPolicy -Scope CurrentUser -ExecutionPolicy RemoteSigned -Force
            UI-Ok 'ExecutionPolicy updated.'
        } catch {
            UI-Warn "Could not change ExecutionPolicy: $($_.Exception.Message)"
        }
    } else {
        UI-Info 'ExecutionPolicy left unchanged. To allow it later: Set-ExecutionPolicy -Scope CurrentUser RemoteSigned'
    }
}

# PowerShell profile: add `up` function.
$profilePath = $PROFILE.CurrentUserAllHosts
$profileDir = Split-Path $profilePath
if (-not (Test-Path $profileDir)) { New-Item -ItemType Directory -Path $profileDir -Force | Out-Null }
if (-not (Test-Path $profilePath)) { New-Item -ItemType File -Path $profilePath -Force | Out-Null }

$entry = "$REPO\src\emerger.ps1"
# Stop rather than silently shadow another command named `up`.
$other = Get-Command up -ErrorAction SilentlyContinue | Where-Object { "$($_.Definition)" -notmatch 'emerger\.ps1' } | Select-Object -First 1
if ($other) {
    UI-Err "A command named 'up' already exists: $($other.Source) $($other.CommandType)"
    UI-Info "eMerger did not add its function. Remove or rename the other 'up' and run install.ps1 again."
    exit 1
}
$existing = Get-Content $profilePath -Raw -ErrorAction SilentlyContinue
if ($existing -and $existing -match 'emerger\.ps1') {
    UI-Ok "'up' already registered in $profilePath"
} else {
    # Single-quoted, every quote the parser accepts (' and U+2018 to U+201B)
    # doubled: the path is data, never code.
    $literal = "'" + [System.Management.Automation.Language.CodeGeneration]::EscapeSingleQuotedStringContent($entry) + "'"
    $block = @"

# eMerger (https://github.com/MasterCruelty/eMerger)
function up { & $literal @args }
"@
    Add-Content -Path $profilePath -Value $block
    UI-Ok "Added 'up' function to $profilePath"
}

# Config + hooks + profiles skeleton.
$configDir = Join-Path $env:APPDATA 'emerger'
@('hooks\pre.d','hooks\post.d','profiles.d') | ForEach-Object {
    $dir = Join-Path $configDir $_
    if (-not (Test-Path $dir)) { New-Item -ItemType Directory -Path $dir -Force | Out-Null }
}

$configFile = Join-Path $configDir 'config.ps1'
if (-not (Test-Path $configFile)) {
    @'
# eMerger user config (Windows). Dot-sourced before argument parsing.
# Uncomment to set defaults.

# $script:ArgsGlobal.Dev       = $true
# $script:ArgsGlobal.KeepTrash = $true
# $script:ArgsGlobal.Security  = $true
'@ | Set-Content $configFile -Encoding UTF8
    UI-Ok "Created $configFile"
}

UI-Info "Open a new PowerShell window (or: . `$PROFILE) and run: up --help"
