# Self-update from git (--self-update).

# Fast-forward the git checkout at $Root (--self-update) and list the new
# commits. Return 0, or 1 when it is not a checkout or git fails.
function SelfUpdate-Run {
    param([string]$Root)
    UI-Title 'Self-update'
    if (-not (Test-Path (Join-Path $Root '.git'))) {
        UI-Err 'Not a git checkout. Re-clone from https://github.com/MasterCruelty/eMerger'
        return 1
    }
    if (-not (Sys-Has git)) { UI-Err 'git not installed'; return 1 }
    if ($script:ArgsGlobal.DryRun) { UI-Sub "[dry-run] git -C `"$Root`" pull --ff-only"; return 0 }
    # Native stderr must not turn into a terminating error (5.1 under Stop):
    # each step is judged by its exit code.
    $ErrorActionPreference = 'Continue'
    $before = "$(& git -C $Root rev-parse HEAD 2>$null)".Trim()
    & git -C $Root fetch --quiet 2>$null
    if ($LASTEXITCODE -ne 0) {
        UI-Err 'git fetch failed'
        return 1
    }
    & git -C $Root pull --ff-only --quiet 2>$null
    if ($LASTEXITCODE -ne 0) {
        UI-Err 'git pull failed (non fast-forward?)'
        return 1
    }
    $after = "$(& git -C $Root rev-parse HEAD 2>$null)".Trim()
    if ($before -eq $after) {
        UI-Ok 'Already up to date.'
    } else {
        UI-Ok ("Updated {0}..{1}" -f $before.Substring(0, [math]::Min(7,$before.Length)), $after.Substring(0, [math]::Min(7,$after.Length)))
        & git -C $Root log --oneline "$before..$after" | ForEach-Object { Write-Host "    $(UI-Color gray (UI-Glyph dot)) $_" }
    }
    return 0
}
