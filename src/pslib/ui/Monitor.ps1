# Live monitor of the Windows UI: spinner, wave, progress bar.
# Keep this file ASCII: PowerShell 5.1 reads BOM-less files as ANSI, so
# glyphs are built from code points.

# Return the spinner frames of EMERGER_SPINNER (dots, line, pulse, braille),
# braille by default on a modern Unicode console, pulse otherwise.
function _UI-Spinner-Frames {
    $style = "$env:EMERGER_SPINNER".ToLower()
    if (-not $style) {
        # conhost can't draw braille.
        if ($script:UI_HAS_UNICODE -and $script:UI_IS_MODERN) { $style = 'braille' } else { $style = 'pulse' }
    }
    if (-not $script:UI_HAS_UNICODE -and $style -ne 'line') { $style = 'pulse' }
    switch ($style) {
        'dots'  { return @(0x2801, 0x2808, 0x2810, 0x2820, 0x2880, 0x2840, 0x2804, 0x2802 | ForEach-Object { _UI-Char $_ }) }
        'line'  { return @('|', '/', '-', '\') }
        'pulse' { return @('.  ', '.. ', '.:.', ':::', ' ::', '  :', '   ', '  .', ' ..', '.:.', ':::', ':: ', ':  ', '   ') }
        default { return @(0x2809, 0x2818, 0x2830, 0x28A0, 0x28C0, 0x2844, 0x2806, 0x2803 | ForEach-Object { _UI-Char $_ }) }
    }
}

# Return the frames of ".:::." bouncing across 8 columns, for steps with no
# known progress.
function _UI-Wave-Frames {
    $track = 8; $shape = '.:::.'
    $frames = New-Object System.Collections.Generic.List[string]
    for ($position = - $shape.Length + 1; $position -lt $track; $position++) {
        $line = (' ' * $track).ToCharArray()
        for ($offset = 0; $offset -lt $shape.Length; $offset++) {
            $column = $position + $offset
            if ($column -ge 0 -and $column -lt $track) { $line[$column] = $shape[$offset] }
        }
        $frames.Add((-join $line))
    }
    for ($i = $frames.Count - 2; $i -gt 0; $i--) { $frames.Add($frames[$i]) }
    return $frames.ToArray()
}

# Return the 10-column bar of $Fraction, clamped to 0..1. Unicode fills in
# eighths of a cell.
function UI-Bar {
    param([double]$Fraction)
    if ($Fraction -lt 0) { $Fraction = 0 }
    if ($Fraction -gt 1) { $Fraction = 1 }
    $width = 10
    if ($script:UI_HAS_UNICODE) {
        $eighths = [int][math]::Floor($Fraction * $width * 8)
        $full = [int][math]::Floor($eighths / 8); $remainder = $eighths % 8
        $bar = (_UI-Char 0x2588) * $full
        $used = $full
        if ($remainder -gt 0 -and $full -lt $width) { $bar += (_UI-Char (0x2590 - $remainder)); $used++ }
        $empty = ' ' * ($width - $used)
        return (UI-Color 'dim gray' (_UI-Char 0x2595)) + (UI-Color green $bar) + $empty + (UI-Color 'dim gray' (_UI-Char 0x258F))
    }
    $full = [int][math]::Floor($Fraction * $width)
    return (UI-Color 'dim gray' '[') + (UI-Color green ('#' * $full)) + (UI-Color 'dim gray' ('.' * ($width - $full))) + (UI-Color 'dim gray' ']')
}

# State of the live monitor, $null when stopped. Run-Cmd calls
# UI-Monitor-Frame every ~100 ms while it polls the child process, progress
# comes from PROGRESS_STATE.
$script:UI_MONITOR = $null

# Start the live monitor for step $Label, $Hint in parentheses after it. It
# draws only on a console, not quiet and not verbose, else prints the label once.
function UI-Monitor-Start {
    param([string]$Label, [string]$Hint)
    $stopwatch = [Diagnostics.Stopwatch]::StartNew()
    $isLive = ($script:QUIET_LEVEL -lt 2) -and -not $script:UI_VERBOSE -and $script:UI_IS_TTY
    $script:UI_MONITOR = @{
        Label = $Label; Hint = $Hint; Stopwatch = $stopwatch; FrameCount = 0; IsLive = $isLive; LastText = ''; Width = (UI-Width)
        SpinnerFrames = (_UI-Spinner-Frames); WaveFrames = (_UI-Wave-Frames)
    }
    if ($script:QUIET_LEVEL -lt 2 -and -not $isLive) { UI-Sub $Label }
    if ($isLive) { UI-Cursor-Hide }
}

# Redraw the monitor line: spinner, label, progress bar or wave, counter,
# elapsed time and the last output text.
function UI-Monitor-Frame {
    $monitor = $script:UI_MONITOR
    if (-not $monitor -or -not $monitor.IsLive) { return }
    if ($monitor.FrameCount % 16 -eq 0) { $monitor.Width = UI-Width }
    $elapsed = [int][math]::Floor($monitor.Stopwatch.Elapsed.TotalSeconds)
    $progress = $script:PROGRESS_STATE

    $progressText = ''
    $fraction = -1
    if ($progress) {
        if ($progress.Fraction -ge 0) { $fraction = $progress.Fraction }
        elseif ($progress.Total -gt 0) {
            # Cur is the item in progress, Pct its own percentage.
            $doneItems = [math]::Max(0, $progress.Current - 1)
            if ($progress.Percent -ge 0 -and $progress.Current -gt 0) { $doneItems += $progress.Percent / 100 }
            $fraction = $doneItems / $progress.Total
        }
        elseif ($progress.Percent -ge 0) { $fraction = $progress.Percent / 100 }
        if ($progress.Total -gt 0) { $progressText = "$($progress.Current)/$($progress.Total)" }
        elseif ($progress.Percent -ge 0) { $progressText = "$([int]$progress.Percent)%" }
        elseif ($fraction -ge 0) { $progressText = "$([int]($fraction * 100))%" }
    }
    if ($fraction -ge 0) {
        $animation = (UI-Bar $fraction)
        $animationWidth = 12
    } else {
        $animation = UI-Color cyan $monitor.WaveFrames[$monitor.FrameCount % $monitor.WaveFrames.Count]
        $animationWidth = 8
    }

    $frame = $monitor.SpinnerFrames[$monitor.FrameCount % $monitor.SpinnerFrames.Count]
    if ($script:UI_GRADIENT.Count -gt 0) {
        $spinColor = "$($script:UI_ESC)[38;5;$($script:UI_GRADIENT[[int][math]::Floor($monitor.FrameCount / 2) % $script:UI_GRADIENT.Count])m$($script:UI_PALETTE.bold)"
        $spinner = "$spinColor$frame$($script:UI_PALETTE.reset)"
    } else { $spinner = UI-Color 'bold cyan' $frame }

    $hintColored = ''
    if ($monitor.Hint) { $hintColored = ' ' + (UI-Color 'dim gray' "($($monitor.Hint))") }
    $time = '{0}:{1:00}' -f [int][math]::Floor($elapsed / 60), ($elapsed % 60)
    $progressColored = ''
    if ($progressText) { $progressColored = ' ' + (UI-Color bold $progressText) }

    $maxShown = $monitor.Width - 4 - $frame.Length - 1 - $monitor.Label.Length - (UI-Visible-Length $hintColored) - 2 - $animationWidth - (UI-Visible-Length $progressColored) - 2 - $time.Length - 2 - 1
    if ($maxShown -lt 0) { $maxShown = 0 }
    $shown = $monitor.LastText
    if ($shown.Length -gt $maxShown) { $shown = $shown.Substring(0, $maxShown) }

    $line = "    $spinner " + (UI-Color bold $monitor.Label) + $hintColored + "  $animation$progressColored  " + (UI-Color gray $time) + '  ' + (UI-Color 'dim gray' $shown)
    if ($script:UI_HAS_VT) {
        [Console]::Write("`r$($script:UI_ESC)[K$line")
    } else {
        $plain = UI-Strip $line
        if ($plain.Length -lt $monitor.Width - 1) { $plain = $plain.PadRight($monitor.Width - 1) }
        [Console]::Write("`r$plain")
    }
    $monitor.FrameCount++
}

# Set the output text the monitor line shows next.
function UI-Monitor-Text {
    param([string]$Text)
    if ($script:UI_MONITOR) { $script:UI_MONITOR.LastText = ($Text -replace '\t', ' ').Trim() }
}

# Stop the monitor, record its elapsed time for UI-Done or UI-Fail and clear
# the line.
function UI-Monitor-Stop {
    $monitor = $script:UI_MONITOR
    if (-not $monitor) { return }
    $monitor.Stopwatch.Stop()
    $script:UI_LAST_ELAPSED = UI-Format-Elapsed $monitor.Stopwatch.Elapsed
    if ($monitor.IsLive) {
        if ($script:UI_HAS_VT) { [Console]::Write("`r$($script:UI_ESC)[K") }
        else { [Console]::Write("`r" + (' ' * ($monitor.Width - 1)) + "`r") }
        UI-Cursor-Show
    }
    $script:UI_MONITOR = $null
}
