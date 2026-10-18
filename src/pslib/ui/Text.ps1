# Text measurement and escape stripping for the Windows UI.

# Remove CSI escape sequences from $Text.
function UI-Strip {
    param([string]$Text)
    return [regex]::Replace($Text, "$([char]27)\[[0-9;?]*[a-zA-Z]", '')
}

# Remove CSI and OSC sequences, any other escape sequence (ESC, intermediate
# bytes, final byte), then every control character but tab and newline
# (C0, DEL and C1), from text that came from outside.
# Each pattern is linear in the length of $Text.
function UI-Sanitize {
    param([string]$Text)
    $esc = [char]27
    $stripped = [regex]::Replace($Text, "$esc\[[0-?]*[ -/]*[@-~]", '')
    $stripped = [regex]::Replace($stripped, "$esc\][^\a$esc]*(\a|$esc\\)?", '')
    $stripped = [regex]::Replace($stripped, "$esc[ -/]*[0-~]", '')
    return [regex]::Replace($stripped, '[\x00-\x08\x0B-\x1F\x7F-\x9F]', '')
}

# Return the length of $Text without escape sequences. Emoji are two UTF-16
# units and two columns wide, so .Length counts columns.
function UI-Visible-Length { param([string]$Text) return (UI-Strip $Text).Length }

# Format $Elapsed as 4.2s, 42s or 1m03s.
function UI-Format-Elapsed {
    param([TimeSpan]$Elapsed)
    $seconds = [int][math]::Floor($Elapsed.TotalSeconds)
    if ($seconds -lt 10) { return ('{0}.{1}s' -f $seconds, ([int][math]::Floor($Elapsed.TotalMilliseconds / 100) % 10)) }
    if ($seconds -lt 60) { return "${seconds}s" }
    return ('{0}m{1:00}s' -f [int][math]::Floor($seconds / 60), ($seconds % 60))
}
