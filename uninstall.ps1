#Requires -Version 5.1
<#
.SYNOPSIS
  Remove the eMerger Windows integration: `up` function, scheduled task.
  Config and state under %APPDATA%\emerger and %LOCALAPPDATA%\emerger are kept.
#>
[CmdletBinding()]
param()

$ErrorActionPreference = 'Stop'
$REPO = Split-Path -Parent $PSCommandPath
. "$REPO\src\pslib\UI.ps1"

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
    $t = Get-ScheduledTask -TaskName 'eMerger' -ErrorAction Stop
    if ($t) {
        Unregister-ScheduledTask -TaskName 'eMerger' -Confirm:$false
        UI-Ok "Removed scheduled task 'eMerger'"
    }
} catch {}

UI-Muted "Config kept at:  $env:APPDATA\emerger\"
UI-Muted "State kept at:   $env:LOCALAPPDATA\emerger\"
UI-Muted "Delete manually if you want a truly clean wipe."

UI-Ok "Uninstall complete. Repo still at $REPO."
