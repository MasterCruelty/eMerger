# eMerger Windows UI helpers: colors, glyphs, box, step, spinner.
# Stays in script scope; all state is kept on $script:.

$script:UI_COLOR = $true
if ($env:NO_COLOR) { $script:UI_COLOR = $false }
try { if ([Console]::IsOutputRedirected) { $script:UI_COLOR = $false } } catch {}

$script:UI_UNICODE = -not [bool]$env:EMERGER_NO_EMOJI
$script:QUIET_LEVEL = 0
$script:UI_VERBOSE = $false

function UI-Color {
    param([string]$Color, [string]$Text)
    if (-not $script:UI_COLOR) { return $Text }
    $esc = [char]27
    $map = @{ red=91; green=92; yellow=93; blue=94; magenta=95; cyan=96; gray=90; bold=1; dim=2 }
    $c = $map[$Color]
    if (-not $c) { return $Text }
    return "$esc[${c}m$Text$esc[0m"
}

function UI-Glyph {
    param([string]$Name)
    if ($script:UI_UNICODE) {
        switch ($Name) {
            'check'  { '✔' }
            'cross'  { '✖' }
            'arrow'  { '▶' }
            'info'   { 'ℹ' }
            'warn'   { '⚠' }
            'dot'    { '·' }
            'bullet' { '•' }
            default  { '*' }
        }
    } else {
        switch ($Name) {
            'check'  { '[OK]' }
            'cross'  { '[X]' }
            'arrow'  { '>' }
            'info'   { 'i' }
            'warn'   { '!' }
            'dot'    { '.' }
            'bullet' { '*' }
            default  { '*' }
        }
    }
}

function UI-Width {
    try { $w = [Console]::WindowWidth } catch { $w = 80 }
    if ($w -lt 20) { $w = 80 }
    if ($w -gt 80) { return 80 }
    return $w
}

function UI-Hr {
    if ($script:QUIET_LEVEL -ge 2) { return }
    $w = UI-Width
    Write-Host (UI-Color gray ('─' * $w))
}

function UI-Title {
    param([string]$Text)
    if ($script:QUIET_LEVEL -ge 2) { return }
    Write-Host ""
    Write-Host ("$(UI-Color cyan (UI-Glyph arrow)) $(UI-Color cyan (UI-Color bold $Text))")
    UI-Hr
}

function UI-Info  { param([string]$T) if ($script:QUIET_LEVEL -lt 2) { Write-Host "  $(UI-Color blue (UI-Glyph info)) $T" } }
function UI-Ok    { param([string]$T) if ($script:QUIET_LEVEL -lt 2) { Write-Host "  $(UI-Color green (UI-Glyph check)) $T" } }
function UI-Warn  { param([string]$T) Write-Host "  $(UI-Color yellow (UI-Glyph warn)) $T" }
function UI-Err   { param([string]$T) [Console]::Error.WriteLine("  $(UI-Color red (UI-Glyph cross)) $T") }
function UI-Muted { param([string]$T) if ($script:QUIET_LEVEL -lt 1) { Write-Host (UI-Color gray "  $T") } }
function UI-Sub   { param([string]$T) if ($script:QUIET_LEVEL -lt 1) { Write-Host "    $(UI-Color gray (UI-Glyph dot)) $T" } }
function UI-Done  { param([string]$T) if ($script:QUIET_LEVEL -lt 2) { Write-Host "    $(UI-Color green (UI-Glyph check)) $T" } }
function UI-Fail  { param([string]$T,[int]$Rc=1) Write-Host "    $(UI-Color red (UI-Glyph cross)) $T $(UI-Color gray "(rc=$Rc)")" }

function UI-Step {
    param([int]$I,[int]$N,[string]$Text)
    if ($script:QUIET_LEVEL -ge 2) { return }
    Write-Host ""
    Write-Host "$(UI-Color magenta "[$I/$N]") $(UI-Color bold $Text)"
}

function UI-Logo {
    param([string]$Path)
    if ($script:QUIET_LEVEL -ge 1) { return }
    if (-not (Test-Path $Path)) { return }
    if ((UI-Width) -lt 60) { return }
    Write-Host (UI-Color cyan (Get-Content $Path -Raw))
}

function UI-Box {
    param([string]$Title, [string[]]$Lines)
    if ($script:QUIET_LEVEL -ge 3) { return }
    $strip = { param($s) [regex]::Replace($s, "`e\[[0-9;]*[a-zA-Z]", '') }
    $maxlen = $Title.Length
    foreach ($l in $Lines) {
        $len = (& $strip $l).Length
        if ($len -gt $maxlen) { $maxlen = $len }
    }
    if ($maxlen -lt 30) { $maxlen = 30 }
    $bar = '─' * ($maxlen + 2)
    Write-Host ""
    Write-Host "  $(UI-Color cyan "╭$bar╮")"
    Write-Host ("  $(UI-Color cyan '│') " + (UI-Color bold ($Title.PadRight($maxlen))) + " $(UI-Color cyan '│')")
    Write-Host "  $(UI-Color cyan "│$bar│")"
    foreach ($l in $Lines) {
        $stripped = & $strip $l
        $pad = ' ' * ($maxlen - $stripped.Length)
        Write-Host ("  $(UI-Color cyan '│') $l$pad $(UI-Color cyan '│')")
    }
    Write-Host "  $(UI-Color cyan "╰$bar╯")"
}
