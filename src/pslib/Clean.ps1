# Clean %TEMP% folders and the Recycle Bin.

function _Clean-Confirm {
    param([string]$Prompt)
    if ($script:ArgsGlobal.Yes) { return $true }
    $a = Read-Host "    $Prompt [y/N]"
    return $a -match '^[Yy]'
}

function _Folder-Size-MB {
    param([string]$Path)
    if (-not (Test-Path $Path)) { return 0 }
    try {
        $sum = (Get-ChildItem $Path -Recurse -Force -ErrorAction SilentlyContinue |
                Measure-Object Length -Sum).Sum
        if (-not $sum) { return 0 }
        return [math]::Round($sum / 1MB, 1)
    } catch { return 0 }
}

function Clean-Temp {
    UI-Title 'Temp folders'
    $paths = @($env:TEMP, (Join-Path $env:LOCALAPPDATA 'Temp'), (Join-Path $env:SystemRoot 'Temp')) |
        Where-Object { $_ } | Select-Object -Unique
    $before = 0
    foreach ($p in $paths) { $before += (_Folder-Size-MB $p) }
    UI-Muted ("Paths: {0}  Size: {1} MB" -f ($paths -join ', '), $before)

    if ($script:ArgsGlobal.DryRun) { UI-Sub '[dry-run] would clean temp folders'; return }
    if (-not (_Clean-Confirm 'Clean temp folders?')) { UI-Muted 'skipped'; return }

    foreach ($p in $paths) {
        if (-not (Test-Path $p)) { continue }
        Get-ChildItem $p -Force -ErrorAction SilentlyContinue | ForEach-Object {
            try { Remove-Item $_.FullName -Recurse -Force -ErrorAction Stop } catch {}
        }
    }
    $after = 0
    foreach ($p in $paths) { $after += (_Folder-Size-MB $p) }
    $script:SUMMARY_FREED_MB += [math]::Max(0, $before - $after)
    UI-Ok ("temp cleaned ({0} MB)" -f [math]::Max(0, $before - $after))
}

function Clean-RecycleBin {
    UI-Title 'Recycle bin'
    if ($script:ArgsGlobal.DryRun) { UI-Sub '[dry-run] would empty recycle bin'; return }
    if (-not (_Clean-Confirm 'Empty recycle bin?')) { UI-Muted 'skipped'; return }
    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        UI-Ok 'recycle bin emptied'
    } catch {
        UI-Warn "could not empty recycle bin: $($_.Exception.Message)"
    }
}
