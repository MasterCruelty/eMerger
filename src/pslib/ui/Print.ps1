# Message printers of the Windows UI: sections, status lines, logo,
# header, box.

# Step counter the next section header shows, 0 for none.
$script:UI_STEP_INDEX = 0
$script:UI_STEP_TOTAL = 0

# Print a horizontal rule at header width.
function UI-Rule {
    if ($script:QUIET_LEVEL -ge 2) { return }
    $width = _UI-Columns
    Write-Host ("  " + (UI-Color 'dim gray' ((UI-Glyph hline) * ($width - 2))))
}

# Set the step counter the next section header shows to $Index of $Total.
# $Text, the step's name, is not shown.
function UI-Step {
    param([int]$Index, [int]$Total, [string]$Text)
    $script:UI_STEP_INDEX = $Index
    $script:UI_STEP_TOTAL = $Total
}

# Print the header of section $Name with $Icon, $Note and the pending step
# counter: <icon> apt  ~42s ---------------- ##. 1/3
function UI-Section {
    param([string]$Icon, [string]$Name, [string]$Note)
    if ($script:QUIET_LEVEL -ge 2) { $script:UI_STEP_TOTAL = 0; return }
    if (-not $Icon) { $Icon = UI-Glyph arrow }
    $width = _UI-Columns
    $left = "  $Icon $Name"
    if ($Note) { $left += "  $Note" }

    $right = ''; $rightColored = ''
    if ($script:UI_STEP_TOTAL -gt 0) {
        $bar = ''
        if ($script:UI_STEP_TOTAL -le 12) {
            for ($i = 1; $i -le $script:UI_STEP_TOTAL; $i++) {
                if ($i -le $script:UI_STEP_INDEX) { $bar += (UI-Glyph pfull) } else { $bar += (UI-Glyph pempty) }
            }
            $bar += ' '
        }
        $counter = "$($script:UI_STEP_INDEX)/$($script:UI_STEP_TOTAL)"
        $right = " $bar$counter"
        $rightColored = ' ' + (UI-Color magenta $bar) + (UI-Color 'bold magenta' $counter)
        $script:UI_STEP_INDEX = 0; $script:UI_STEP_TOTAL = 0
    }

    $fill = $width - (UI-Visible-Length $left) - (UI-Visible-Length $right) - 2
    if ($fill -lt 3) { $fill = 3 }
    $out = "`n  " + (UI-Color 'bold cyan' $Icon) + ' ' + (UI-Color bold $Name)
    if ($Note) { $out += '  ' + (UI-Color 'dim gray' $Note) }
    $out += ' ' + (UI-Color 'dim gray' ((UI-Glyph hline) * $fill)) + $rightColored
    Write-Host $out
}

# Print a section header with the default icon.
function UI-Title { param([string]$Text) UI-Section '' $Text }

# Write $Line to stderr.
function _UI-Err-Line { param([string]$Line) [Console]::Error.WriteLine($Line) }

# Print status line $Text. Info, Ok, Muted and Sub go to stdout and follow the
# quiet level, Warn and Err go to stderr and always show.
function UI-Info  { param([string]$Text) if ($script:QUIET_LEVEL -lt 2) { Write-Host ("    " + (UI-Color blue (UI-Glyph info)) + " $Text") } }
function UI-Ok    { param([string]$Text) if ($script:QUIET_LEVEL -lt 2) { Write-Host ("    " + (UI-Color green (UI-Glyph check)) + " $Text") } }
function UI-Warn  { param([string]$Text) _UI-Err-Line ("    " + (UI-Color yellow (UI-Glyph warn)) + " $Text") }
function UI-Err   { param([string]$Text) _UI-Err-Line ("    " + (UI-Color 'bold red' (UI-Glyph cross)) + " $Text") }
function UI-Muted { param([string]$Text) if ($script:QUIET_LEVEL -lt 1) { Write-Host ("    " + (UI-Color 'dim gray' $Text)) } }
function UI-Sub   { param([string]$Text) if ($script:QUIET_LEVEL -lt 1) { Write-Host ("    " + (UI-Color gray (UI-Glyph dot)) + " $Text") } }

# Return the dot leader after $Label, so the results line up.
function _UI-Leader {
    param([string]$Label)
    $count = 26 - (UI-Visible-Length $Label)
    if ($count -lt 2) { $count = 2 }
    return ((UI-Glyph dot) * $count)
}

# Print the success line of step $Label: elapsed time of the last monitored
# step and $Stat after the dot leader.
function UI-Done {
    param([string]$Label, [string]$Stat)
    $elapsed = $script:UI_LAST_ELAPSED
    $script:UI_LAST_ELAPSED = ''
    if ($script:QUIET_LEVEL -ge 2) { return }
    $out = "    " + (UI-Color green (UI-Glyph check)) + " $Label " + (UI-Color 'dim gray' (_UI-Leader $Label))
    if ($elapsed)    { $out += ' ' + (UI-Color gray ('{0,6}' -f $elapsed)) }
    if ($Stat) { $out += '  ' + (UI-Color cyan $Stat) }
    Write-Host $out
}

# Print the failure line of step $Label with exit code $Rc to stderr.
function UI-Fail {
    param([string]$Label, [string]$Rc = '1')
    $elapsed = $script:UI_LAST_ELAPSED
    $script:UI_LAST_ELAPSED = ''
    $out = "    " + (UI-Color 'bold red' (UI-Glyph cross)) + ' ' + (UI-Color red $Label) + ' ' + (UI-Color 'dim gray' (_UI-Leader $Label))
    if ($elapsed) { $out += ' ' + (UI-Color gray ('{0,6}' -f $elapsed)) }
    $out += '  ' + (UI-Color red "exit $Rc")
    _UI-Err-Line $out
}

# Print output lines $Lines under a failed step, errors and warnings coloured.
function UI-Fail-Tail {
    param([string[]]$Lines)
    $bar = UI-Color 'dim gray' (UI-Glyph v)
    foreach ($line in $Lines) {
        $shown = $line
        if ($script:UI_HAS_COLOR) {
            $shown = [regex]::Replace($shown, '(ERROR|Error|error|FAILED|Failed|failed)', { param($match) (UI-Color red $match.Value) })
            $shown = [regex]::Replace($shown, '(WARNING|Warning|warning|WARN)', { param($match) (UI-Color yellow $match.Value) })
        }
        _UI-Err-Line "      $bar $shown"
    }
}

# Print the logo at $Path in the UI gradient. Skipped when quiet, narrower
# than 64 columns or without Unicode.
function UI-Logo {
    param([string]$Path)
    if ($script:QUIET_LEVEL -ge 1) { return }
    if (-not (Test-Path -LiteralPath $Path)) { return }
    if ((UI-Width) -lt 64) { return }
    # Block characters, no point in ASCII mode.
    if (-not $script:UI_HAS_UNICODE) { return }
    $lines = [IO.File]::ReadAllLines($Path, [Text.Encoding]::UTF8)
    $gradientCount = $script:UI_GRADIENT.Count
    $out = New-Object System.Text.StringBuilder
    [void]$out.Append("`n")
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($gradientCount -gt 0) {
            [void]$out.Append("  $($script:UI_ESC)[38;5;$($script:UI_GRADIENT[$i % $gradientCount])m$($script:UI_PALETTE.bold)$($lines[$i])$($script:UI_PALETTE.reset)`n")
        } else {
            [void]$out.Append('  ' + (UI-Color 'bold green' $lines[$i]) + "`n")
        }
    }
    Write-Host $out.ToString()
}

# Print the system info line under the logo, $Items separated by dots.
function UI-Header {
    param([string[]]$Items)
    if ($script:QUIET_LEVEL -ge 1) { return }
    $separator = ' ' + (UI-Color 'dim gray' (UI-Glyph dot)) + ' '
    $parts = @($Items | Where-Object { $_ })
    Write-Host ('  ' + (UI-Color cyan (UI-Glyph diamond)) + ' ' + ($parts -join $separator))
}

# Print $Lines in a rounded box of colour $Color, $Title in the top border.
function UI-Box {
    param([string]$Title, [string[]]$Lines, [string]$Color = 'cyan')
    if ($script:QUIET_LEVEL -ge 3) { return }
    $hline = UI-Glyph hline; $vline = UI-Glyph v
    $inner = $Title.Length + 4
    foreach ($line in $Lines) { $width = (UI-Visible-Length $line) + 2; if ($width -gt $inner) { $inner = $width } }
    if ($inner -lt 44) { $inner = 44 }
    $out = "`n  " + (UI-Color $Color ((UI-Glyph tl) + $hline)) + ' ' + (UI-Color bold $Title) + ' ' +
           (UI-Color $Color (($hline * ($inner - $Title.Length - 3)) + (UI-Glyph tr))) + "`n"
    foreach ($line in $Lines) {
        $padding = ' ' * ($inner - 2 - (UI-Visible-Length $line))
        $out += '  ' + (UI-Color $Color $vline) + " $line$padding " + (UI-Color $Color $vline) + "`n"
    }
    $out += '  ' + (UI-Color $Color ((UI-Glyph bl) + ($hline * $inner) + (UI-Glyph br)))
    Write-Host $out
}
