# Empty the Recycle Bin. Prompts unless -y.

# Return the Recycle Bin's item count and size ({Count, KB}, size in KiB), or
# $null when the shell does not report them.
function _RecycleBin-Info {
    try {
        $shell = New-Object -ComObject Shell.Application
        $items = @($shell.NameSpace(10).Items())
        $size = 0
        foreach ($item in $items) { try { $size += [double]$item.ExtendedProperty('Size') } catch {} }
        return @{ Count = $items.Count; KB = [int64][math]::Round($size / 1KB) }
    } catch { return $null }
}

# Empty the Recycle Bin after a prompt (-y says yes) and add its size to
# SUMMARY_FREED_KB. A failure is a warning, never an error.
function Clean-RecycleBin {
    UI-Title 'Recycle bin'
    $info = _RecycleBin-Info
    $detail = ''
    if ($info) {
        if ($info.Count -eq 0) { UI-Ok 'empty'; return }
        $detail = "($(Size-Format-KB $info.KB), $($info.Count) items)"
    }
    if (-not (UI-Confirm 'Empty recycle bin?' 'n' $detail)) { UI-Muted 'skipped'; return }
    if ($script:ArgsGlobal.DryRun) { UI-Sub '[dry-run] would empty recycle bin'; return }
    try {
        $stopwatch = [Diagnostics.Stopwatch]::StartNew()
        Clear-RecycleBin -Force -ErrorAction Stop
        if ($info) { $script:SUMMARY_FREED_KB += $info.KB }
        $script:UI_LAST_ELAPSED = UI-Format-Elapsed $stopwatch.Elapsed
        $stat = ''
        if ($info) { $stat = Size-Format-KB $info.KB }
        UI-Done 'recycle bin emptied' $stat
    } catch {
        UI-Warn "could not empty recycle bin: $($_.Exception.Message)"
    }
}
