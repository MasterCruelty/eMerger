# Progress parsers for the Windows managers. Run-Cmd
# passes every output line (ANSI stripped) to Progress-Feed. Counters match at
# most 9 digits so every [int] cast fits: a longer one leaves the line unparsed.

# Progress of the current or last step, $null before the first. Current of Total is
# the item counter, Percent the current item's percent (-1 unknown), Fraction
# the overall fraction when a parser knows better (-1 otherwise).
$script:PROGRESS_STATE = $null

# Start progress tracking for manager $Manager, $Total items when known (0 if not).
function Progress-Reset {
    param([string]$Manager, [int]$Total = 0)
    $script:PROGRESS_STATE = @{
        Manager = $Manager; Total = $Total; Current = 0; Percent = -1; Fraction = -1
        Name = ''; DoneCount = 0; FailedCount = 0; DownloadedCount = 0; FinalText = ''; IsUpToDate = $false; HasAcceptedTotal = $false
    }
}

# Convert $Number in $Unit ("12.3" "MB", "58" "MiB") to bytes, 0 when $Number
# is not a number.
function _Progress-Bytes {
    param([string]$Number, [string]$Unit)
    $value = 0.0
    if (-not [double]::TryParse(($Number -replace ',', '.'), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$value)) { return 0 }
    switch -Regex ($Unit) {
        '^T' { return $value * 1TB }
        '^G' { return $value * 1GB }
        '^M' { return $value * 1MB }
        '^K' { return $value * 1KB }
        default { return $value }
    }
}

# Patterns of a "cur / max" byte pair, a percentage, a choco "Progress: N%"
# line and an "(i/N)" counter. A lookbehind keeps a number from starting inside
# a longer run, an atomic group stops the backtracking: all linear.
$script:PROGRESS_RX_BYTES   = '(?<![\d.,])([\d.,]+)\s*([KMGT]?i?B)\s*/\s*([\d.,]+)\s*([KMGT]?i?B)'
$script:PROGRESS_RX_PERCENT = '(?<!\d)(\d{1,3}(?:[.,]\d+)?)\s?%'
$script:PROGRESS_RX_CHOCO   = '^\s*Progress:\s*(?:Downloading\s+((?>[^\s.]+))[^%]*?)?(\d{1,3})%'
$script:PROGRESS_RX_COUNTER = '[\[(]\s*(\d{1,9})\s*/\s*(\d{1,9})\s*[\])]'

# Return the percent done that $Line shows, from a "cur / max" byte pair or
# the last "N%": whole number 0 to 100, -1 when the line has neither.
function _Progress-Percent {
    param([string]$Line)
    if ($Line -match $script:PROGRESS_RX_BYTES) {
        $current = _Progress-Bytes $Matches[1] $Matches[2]
        $maximum = _Progress-Bytes $Matches[3] $Matches[4]
        if ($maximum -gt 0) { return [math]::Min(100, [math]::Floor($current * 100 / $maximum)) }
    }
    $percents = [regex]::Matches($Line, $script:PROGRESS_RX_PERCENT)
    if ($percents.Count -gt 0) {
        $value = 0.0
        if ([double]::TryParse(($percents[$percents.Count - 1].Groups[1].Value -replace ',', '.'), [Globalization.NumberStyles]::Float, [Globalization.CultureInfo]::InvariantCulture, [ref]$value)) {
            if ($value -le 100) { return [math]::Floor($value) }
        }
    }
    return -1
}

# Update $Progress from winget line $Line ("N upgrades available.", "(i/N)
# Found Name [Id]", "12.0 MB / 58.3 MB"). Return what Progress-Feed returns.
function _Progress-Feed-Winget {
    param($Progress, [string]$Line)
    if ($Line -match '^\s*(\d{1,9}) upgrades? available') { $Progress.Total = [int]$Matches[1]; return '' }
    if ($Line -match '^\s*(?:\((\d{1,9})/(\d{1,9})\)\s*)?Found (.+?) \[([^\]]+)\]') {
        if ($Matches[1]) { $Progress.Current = [int]$Matches[1]; $Progress.Total = [int]$Matches[2] }
        elseif ($Progress.Total -gt 0) { $Progress.Current = [math]::Min($Progress.Total, $Progress.Current + 1) }
        $Progress.Name = $Matches[3].Trim(); $Progress.Percent = -1
        return $Progress.Name
    }
    if ($Line -match 'Successfully installed') { $Progress.DoneCount++; $Progress.Percent = 100; return "$($Progress.Name) installed" }
    if ($Line -match 'Installer failed|failed with exit code|Installation failed') { $Progress.FailedCount++; return '' }
    if ($Line -match 'Starting package install') { $Progress.Percent = 90; return "installing $($Progress.Name)" }
    if ($Line -match '^\s*Downloading\s') { return "downloading $($Progress.Name)" }
    if ($Line -match 'No (installed package found|available upgrade found|applicable upgrade)') { $Progress.IsUpToDate = $true; return '' }
    $percent = _Progress-Percent $Line
    if ($percent -ge 0) {
        $Progress.Percent = $percent
        if ($Progress.Name) { return "$($Progress.Name) $percent%" }
        return ''
    }
    # winget's own spinner.
    if ($Line -match '^\s*[-\\|/]\s*$') { return ' ' }
    return ''
}

# Update $Progress from choco line $Line ("You have X v1 installed. Version 2
# is available", "Progress: 45%", "Chocolatey upgraded 2/45 packages."). Return
# what Progress-Feed returns.
function _Progress-Feed-Choco {
    param($Progress, [string]$Line)
    if ($Line -match 'You have (\S+) v(\S+) installed\. Version (\S+) is available') {
        $Progress.Current++; $Progress.Name = $Matches[1]; $Progress.Percent = -1
        if ($Progress.Total -lt $Progress.Current) { $Progress.Total = $Progress.Current }
        return "$($Matches[1]) $($Matches[2]) -> $($Matches[3])"
    }
    if ($Line -match '^\s*(\S+) v(\S+) is the latest version available') {
        $Progress.Current++; $Progress.Percent = 100
        if ($Progress.Total -lt $Progress.Current) { $Progress.Total = $Progress.Current }
        return "$($Matches[1]) up to date"
    }
    if ($Line -match $script:PROGRESS_RX_CHOCO) {
        $Progress.Percent = [int]$Matches[2]
        if ($Matches[1]) { $Progress.Name = $Matches[1] }
        return "$($Progress.Name) $($Progress.Percent)%"
    }
    if ($Line -match 'The upgrade of (\S+) was successful') { $Progress.DoneCount++; $Progress.Percent = 100; return "$($Matches[1]) upgraded" }
    if ($Line -match 'The upgrade of (\S+) was NOT successful') { $Progress.FailedCount++; return '' }
    if ($Line -match 'Chocolatey upgraded (\d{1,9})/(\d{1,9}) packages') {
        $Progress.DoneCount = [int]$Matches[1]; $Progress.Total = [int]$Matches[2]; $Progress.Current = $Progress.Total; $Progress.Percent = 100
        if ($Progress.DoneCount -gt 0) { $Progress.FinalText = "$($Progress.DoneCount) upgraded" } else { $Progress.FinalText = 'up to date' }
        return ''
    }
    return ''
}

# Update $Progress from scoop line $Line ("Updating N outdated apps:",
# "Updating 'x' (1 -> 2)", "'x' (2) was installed"). Return what Progress-Feed
# returns.
function _Progress-Feed-Scoop {
    param($Progress, [string]$Line)
    if ($Line -match 'Updating (\d{1,9}) outdated apps?') { $Progress.Total = [int]$Matches[1]; return '' }
    if ($Line -match 'Updating one outdated app') { $Progress.Total = 1; return '' }
    if ($Line -match "^\s*Updating '([^']+)' \(([^)]*)\)") {
        $Progress.Name = $Matches[1]; $Progress.Percent = -1
        $Progress.Current++
        if ($Progress.Total -lt $Progress.Current) { $Progress.Total = $Progress.Current }
        return "$($Matches[1]) $($Matches[2])"
    }
    if ($Line -match "^\s*Updating '([^']+)' bucket") { return "bucket $($Matches[1])" }
    if ($Line -match "'([^']+)' \(([^)]*)\) was installed successfully") { $Progress.DoneCount++; $Progress.Percent = 100; return "$($Matches[1]) $($Matches[2]) installed" }
    if ($Line -match 'Latest versions for all apps are installed') { $Progress.IsUpToDate = $true; return '' }
    $percent = _Progress-Percent $Line
    if ($percent -ge 0) { $Progress.Percent = $percent; if ($Progress.Name) { return "$($Progress.Name) $percent%" } }
    return ''
}

# Update $Progress from PSWindowsUpdate line $Line: rows "1 PC Accepted
# KB5000001 ...", then Downloaded and Installed, with -Verbose also "Accepted
# [N] Updates". Return what Progress-Feed returns.
function _Progress-Feed-WindowsUpdate {
    param($Progress, [string]$Line)
    if ($Line -match 'Accepted \[(\d{1,9})\]') { $Progress.Total = [int]$Matches[1]; $Progress.HasAcceptedTotal = $true; return '' }
    if ($Line -match 'Found \[(\d{1,9})\] Updates? in post search') { if ($Progress.Total -eq 0) { $Progress.Total = [int]$Matches[1] }; return '' }
    # Result rows: X ComputerName Result KB Size Title.
    if ($Line -match '^\s*\d?\s*[^\s\[\]:]+\s+(Accepted|Downloaded|Installed|Failed)\s+(KB\d+)?') {
        $article = $Matches[2]
        switch ($Matches[1]) {
            'Accepted'   { if (-not $Progress.HasAcceptedTotal) { $Progress.Total++ } }
            'Downloaded' { $Progress.DownloadedCount++ }
            'Installed'  { $Progress.DoneCount++ }
            'Failed'     { $Progress.FailedCount++ }
        }
        if ($Progress.Total -gt 0) {
            $Progress.Current = [math]::Min($Progress.Total, $Progress.DoneCount + $Progress.FailedCount)
            $Progress.Fraction = [math]::Min(1.0, ($Progress.DownloadedCount + $Progress.DoneCount + $Progress.FailedCount) / (2 * $Progress.Total))
        }
        return "$($Matches[1].ToLower()) $article".Trim()
    }
    $percent = _Progress-Percent $Line
    if ($percent -ge 0) { $Progress.Percent = $percent }
    return ''
}

# Update $Progress from line $Line of any other manager: "[i/N] name" from the
# pip loop, "(i/N)" counters, NN%. Return what Progress-Feed returns.
function _Progress-Feed-Generic {
    param($Progress, [string]$Line)
    if ($Line -match '^\s*\[(\d{1,9})/(\d{1,9})\]\s*(.*)$') {
        $Progress.Current = [int]$Matches[1]; $Progress.Total = [int]$Matches[2]; $Progress.Percent = -1; $Progress.Name = $Matches[3]
        return $Matches[3]
    }
    if ($Line -match $script:PROGRESS_RX_COUNTER -and [int]$Matches[2] -gt 0 -and [int]$Matches[1] -le [int]$Matches[2]) {
        $Progress.Current = [int]$Matches[1]; $Progress.Total = [int]$Matches[2]
    }
    $percent = _Progress-Percent $Line
    if ($percent -ge 0) { $Progress.Percent = $percent }
    if ($Line -match 'nothing to upgrade|already up.to.date|up to date') { $Progress.IsUpToDate = $true }
    return ''
}

# Feed output line $Line to the current manager's parser. Return the text
# to show instead, '' for the raw line, ' ' to hide it.
function Progress-Feed {
    param([string]$Line)
    $progress = $script:PROGRESS_STATE
    if (-not $progress) { return '' }
    switch ($progress.Manager) {
        'winget'          { return (_Progress-Feed-Winget  $progress $Line) }
        'choco'           { return (_Progress-Feed-Choco   $progress $Line) }
        'scoop'           { return (_Progress-Feed-Scoop   $progress $Line) }
        'PSWindowsUpdate' { return (_Progress-Feed-WindowsUpdate      $progress $Line) }
        default           { return (_Progress-Feed-Generic $progress $Line) }
    }
}

# Return the short stat of the step's result line, '' when there is none.
function Progress-Summarize {
    $progress = $script:PROGRESS_STATE
    if (-not $progress) { return '' }
    if ($progress.FinalText) { return $progress.FinalText }
    switch ($progress.Manager) {
        'winget' {
            if ($progress.DoneCount -gt 0 -or $progress.FailedCount -gt 0) {
                $stat = "$($progress.DoneCount) upgraded"
                if ($progress.FailedCount -gt 0) { $stat += ", $($progress.FailedCount) failed" }
                return $stat
            }
            if ($progress.IsUpToDate) { return 'up to date' }
        }
        'scoop' {
            if ($progress.DoneCount -gt 0) { return "$($progress.DoneCount) updated" }
            if ($progress.IsUpToDate) { return 'up to date' }
        }
        'PSWindowsUpdate' {
            if ($progress.DoneCount -gt 0 -or $progress.FailedCount -gt 0) {
                $stat = "$($progress.DoneCount) installed"
                if ($progress.FailedCount -gt 0) { $stat += ", $($progress.FailedCount) failed" }
                return $stat
            }
        }
        'pip' {
            if ($progress.Total -gt 0) { return "$($progress.Total) upgraded" }
            if ($progress.IsUpToDate) { return 'up to date' }
        }
        default {
            if ($progress.IsUpToDate) { return 'up to date' }
        }
    }
    return ''
}

# Return the number of packages the step changed, for the summary.
function Progress-Changed {
    $progress = $script:PROGRESS_STATE
    if (-not $progress) { return 0 }
    switch ($progress.Manager) {
        'winget'          { return $progress.DoneCount }
        'choco'           { return $progress.DoneCount }
        'scoop'           { return $progress.DoneCount }
        'PSWindowsUpdate' { return $progress.DoneCount }
        'pip'             { return $progress.Total }
        default           { return 0 }
    }
}
