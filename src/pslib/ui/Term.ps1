# Windows UI terminal setup (VT mode, colours, glyphs, width).
# Keep this file ASCII: PowerShell 5.1 reads BOM-less files as ANSI, so
# glyphs are built from code points.

# Quiet level (0 to 3), the -v and --ascii switches, the elapsed time of the
# last monitored step, and the escape character.
$script:QUIET_LEVEL = 0
$script:UI_VERBOSE  = $false
$script:UI_IS_ASCII = $false
$script:UI_LAST_ELAPSED = ''
$script:UI_ESC = [string][char]27

# Return the character of code point $CodePoint as a string (two UTF-16 units
# above U+FFFF).
function _UI-Char { param([int]$CodePoint) [char]::ConvertFromUtf32($CodePoint) }

# Return $true on Windows: always under 5.1, from $IsWindows under 6 and later.
function _UI-IsWindows {
    if ($PSVersionTable.PSVersion.Major -lt 6) { return $true }
    return [bool]$IsWindows
}

# Enable ENABLE_VIRTUAL_TERMINAL_PROCESSING, which conhost needs for ANSI
# colours (PowerShell 7 and Windows Terminal set it, 5.1 may not). Return
# $true when both console handles take escape sequences.
function _UI-Enable-VT {
    if (-not (_UI-IsWindows)) { return $true }
    if ($PSVersionTable.PSVersion.Major -ge 7 -or $env:WT_SESSION) { return $true }
    try {
        if (-not ('Emerger.VT' -as [type])) {
            Add-Type -Namespace 'Emerger' -Name 'VT' -MemberDefinition @'
[DllImport("kernel32.dll", SetLastError = true)] public static extern IntPtr GetStdHandle(int nStdHandle);
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool GetConsoleMode(IntPtr hConsoleHandle, out uint lpMode);
[DllImport("kernel32.dll", SetLastError = true)] public static extern bool SetConsoleMode(IntPtr hConsoleHandle, uint dwMode);
'@ -ErrorAction Stop
        }
        $isOk = $true
        foreach ($stdHandleId in @(-11, -12)) {
            $handle = [Emerger.VT]::GetStdHandle($stdHandleId)
            $mode = [uint32]0
            if ([Emerger.VT]::GetConsoleMode($handle, [ref]$mode)) {
                if (-not [Emerger.VT]::SetConsoleMode($handle, ($mode -bor 4))) { $isOk = $false }
            }
        }
        return $isOk
    } catch { return $false }
}

# Return $true when the console can draw emoji: EMERGER_EMOJI decides, else
# Windows Terminal and VS Code can and conhost, which draws boxes, cannot.
function _UI-Detect-Emoji {
    if (-not $script:UI_HAS_UNICODE) { return $false }
    switch -Regex (("$env:EMERGER_EMOJI").ToLower()) {
        '^(1|yes|on|true)$'  { return $true }
        '^(0|no|off|false)$' { return $false }
    }
    if ($env:WT_SESSION) { return $true }
    if ($env:TERM_PROGRAM -eq 'vscode') { return $true }
    return $false
}

# Return $true when the terminal background looks light: COLORFGBG first, then the
# console's own background colour.
function _UI-Detect-Light-Background {
    # COLORFGBG="fg;bg": bg 7+ is a light theme. Otherwise trust the console.
    if ($env:COLORFGBG) {
        $background = ($env:COLORFGBG -split ';')[-1]
        if ($background -match '^\d+$') { return ([int]$background -ge 7) }
        return $false
    }
    try {
        $color = [Console]::BackgroundColor
        return @('White', 'Gray', 'Yellow') -contains "$color"
    } catch { return $false }
}

# Detect the console (redirection, UTF-8, emoji, VT) and set the colour
# palette and glyph table. Called at load and again after the flags are parsed.
function UI-Init {
    # Ascii set by config.ps1 or a profile counts as the flag.
    if ($script:ArgsGlobal -and $script:ArgsGlobal.Ascii) { $script:UI_IS_ASCII = $true }
    $script:UI_IS_TTY = $true
    try { if ([Console]::IsOutputRedirected) { $script:UI_IS_TTY = $false } } catch { $script:UI_IS_TTY = $false }

    # UTF-8 so glyphs and child process output survive.
    try {
        if ([Console]::OutputEncoding.CodePage -ne 65001) {
            [Console]::OutputEncoding = New-Object System.Text.UTF8Encoding $false
        }
    } catch {}
    $isUtf8 = $false
    try { $isUtf8 = ([Console]::OutputEncoding.CodePage -eq 65001) } catch {}
    $script:UI_HAS_UNICODE = $isUtf8 -and -not $script:UI_IS_ASCII
    $script:UI_HAS_EMOJI = _UI-Detect-Emoji
    $script:UI_IS_MODERN = [bool]($env:WT_SESSION -or $env:TERM_PROGRAM -eq 'vscode' -or -not (_UI-IsWindows))

    $script:UI_HAS_COLOR = $script:UI_IS_TTY -and -not $env:NO_COLOR -and ($env:TERM -ne 'dumb')
    $script:UI_HAS_VT = $false
    if ($script:UI_IS_TTY) { $script:UI_HAS_VT = _UI-Enable-VT }
    if (-not $script:UI_HAS_VT) { $script:UI_HAS_COLOR = $false }

    $esc = $script:UI_ESC
    $script:UI_PALETTE = @{}
    foreach ($key in 'reset','bold','dim','red','green','yellow','blue','magenta','cyan','gray') { $script:UI_PALETTE[$key] = '' }
    $script:UI_GRADIENT = @()
    if ($script:UI_HAS_COLOR) {
        $script:UI_PALETTE.reset = "$esc[0m"; $script:UI_PALETTE.bold = "$esc[1m"; $script:UI_PALETTE.dim = "$esc[2m"
        if (_UI-Detect-Light-Background) {
            $palette = @{ red=160; green=28; yellow=136; blue=26; magenta=90; cyan=30; gray=240 }
            $script:UI_GRADIENT = @(35, 35, 29, 29, 29, 22, 22)
        } else {
            $palette = @{ red=203; green=114; yellow=221; blue=39; magenta=176; cyan=81; gray=245 }
            $script:UI_GRADIENT = @(121, 84, 48, 42, 35, 29, 29)
        }
        foreach ($key in $palette.Keys) { $script:UI_PALETTE[$key] = "$esc[38;5;$($palette[$key])m" }
    }

    if ($script:UI_HAS_UNICODE) {
        $script:UI_GLYPHS = @{
            check = (_UI-Char 0x2714); cross = (_UI-Char 0x2716); arrow = (_UI-Char 0x25B8)
            info = (_UI-Char 0x25CF); warn = (_UI-Char 0x25B2); ask = (_UI-Char 0x276F)
            bullet = (_UI-Char 0x2022); hline = (_UI-Char 0x2500)
            dot = (_UI-Char 0x00B7); diamond = (_UI-Char 0x25C6)
            pfull = (_UI-Char 0x25B0); pempty = (_UI-Char 0x25B1)
            tl = (_UI-Char 0x256D); tr = (_UI-Char 0x256E); bl = (_UI-Char 0x2570); br = (_UI-Char 0x256F)
            v = (_UI-Char 0x2502)
        }
    } else {
        $script:UI_GLYPHS = @{
            check = '[OK]'; cross = '[X]'; arrow = '>'; info = 'i'; warn = '!'; ask = '?'
            bullet = '*'; hline = '-'; dot = '.'; diamond = '*'
            pfull = '#'; pempty = '.'; tl = '+'; tr = '+'; bl = '+'; br = '+'; v = '|'
        }
    }
}

# Return $Text in colour $Color, a list such as 'bold cyan', or plain when
# colour is off.
function UI-Color {
    param([string]$Color, [string]$Text)
    if (-not $script:UI_HAS_COLOR) { return $Text }
    $prefix = ''
    foreach ($name in ($Color -split '\s+')) { if ($script:UI_PALETTE.ContainsKey($name)) { $prefix += $script:UI_PALETTE[$name] } }
    if (-not $prefix) { return $Text }
    return "$prefix$Text$($script:UI_PALETTE.reset)"
}

# Return glyph $Name from the current table, '*' for an unknown name.
function UI-Glyph {
    param([string]$Name)
    $glyph = $script:UI_GLYPHS[$Name]
    if ($null -eq $glyph) { return '*' }
    return $glyph
}

# Return the console width in columns, 80 when unknown.
function UI-Width {
    try { $width = [Console]::WindowWidth } catch { $width = 80 }
    if ($width -le 0) { $width = 80 }
    return $width
}

# Return the width of headers and boxes: the console width within 40 to 78.
function _UI-Columns {
    $width = UI-Width
    if ($width -gt 78) { $width = 78 }
    if ($width -lt 40) { $width = 40 }
    return $width
}

# Hide or show the cursor on a console, errors ignored.
function UI-Cursor-Hide { if ($script:UI_IS_TTY) { try { [Console]::CursorVisible = $false } catch {} } }
function UI-Cursor-Show { if ($script:UI_IS_TTY) { try { [Console]::CursorVisible = $true } catch {} } }

UI-Init
