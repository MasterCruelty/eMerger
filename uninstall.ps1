#Requires -Version 5.1
<#
.SYNOPSIS
  Remove the eMerger Windows integration: `up` function, scheduled task.
  Config and state under %APPDATA%\emerger and %LOCALAPPDATA%\emerger go only
  when the user answers yes.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$REPO = Split-Path -Parent $PSCommandPath
. "$REPO\src\pslib\ui\Term.ps1"
. "$REPO\src\pslib\ui\Text.ps1"
. "$REPO\src\pslib\ui\Print.ps1"
. "$REPO\src\pslib\ui\Prompt.ps1"

UI-Title 'eMerger uninstall (Windows)'

$profilePath = $PROFILE.CurrentUserAllHosts
if (Test-Path $profilePath) {
    $content = Get-Content $profilePath
    if ($content -match 'emerger\.ps1') {
        $filtered = $content | Where-Object {
            $_ -notmatch 'emerger\.ps1' -and
            $_ -notmatch '^# eMerger\b' -and
            $_ -notmatch '^\s*function\s+up\s*\{'
        }
        $filtered | Set-Content $profilePath -Encoding UTF8
        UI-Ok "Cleaned $profilePath"
    } else {
        UI-Muted "No eMerger entry in $profilePath"
    }
}

# Scheduled task.
try {
    $task = Get-ScheduledTask -TaskName 'eMerger' -ErrorAction Stop
    if ($task) {
        Unregister-ScheduledTask -TaskName 'eMerger' -Confirm:$false
        UI-Ok "Removed scheduled task 'eMerger'"
    }
} catch {}

# Settings, history and cache go only on an explicit yes.
$configDir = Join-Path $env:APPDATA 'emerger'
$stateDir = Join-Path $env:LOCALAPPDATA 'emerger'
if (UI-Confirm 'Delete your settings, history and cache too?' 'n') {
    foreach ($dir in @($configDir, $stateDir)) {
        if (Test-Path -LiteralPath $dir) { Remove-Item -LiteralPath $dir -Recurse -Force }
    }
    UI-Ok 'Removed settings, history and cache'
} else {
    UI-Muted 'Settings, history and cache kept at:'
    UI-Muted "  $configDir\"
    UI-Muted "  $stateDir\"
    UI-Muted 'Remove manually if you want them gone.'
}

UI-Ok "Uninstall complete. Repo still at $REPO."
