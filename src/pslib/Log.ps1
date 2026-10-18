# Structured logging to $EMERGER_LOG, and the --errors viewer.

# Set EMERGER_LOG, create the state directory and the log file when
# missing, and keep the log to its last 2000 lines.
function Log-Init {
    $script:EMERGER_LOG = Join-Path $script:EMERGER_STATE 'emerger.log'
    if (-not (Test-Path -LiteralPath $script:EMERGER_STATE)) {
        [void][IO.Directory]::CreateDirectory($script:EMERGER_STATE)
    }
    if (-not (Test-Path -LiteralPath $script:EMERGER_LOG)) {
        [IO.File]::Open($script:EMERGER_LOG, [IO.FileMode]::OpenOrCreate).Dispose()
    }
    # Rotate at 2000 lines. The parentheses finish the read before the
    # write: 5.1 refuses to rewrite a file still open in the same pipeline.
    $count = (Get-Content -LiteralPath $script:EMERGER_LOG -ErrorAction SilentlyContinue | Measure-Object).Count
    if ($count -gt 2000) {
        (Get-Content -LiteralPath $script:EMERGER_LOG -Tail 2000) | Set-Content -LiteralPath $script:EMERGER_LOG
    }
}

# Lines kept in memory instead of the log file when set (the elevated child).
$script:LOG_BUFFER = $null

# Return the current UTC time as 2026-01-31T12:00:00Z. Invariant culture: a
# custom format's ':' is the culture's time separator, '.' in some locales.
function Log-Timestamp {
    return (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ', [Globalization.CultureInfo]::InvariantCulture)
}

# Write $Message at $Level as one "ts|LEVEL|message" line to the log, or to
# LOG_BUFFER when set. A pipe becomes '/' and a line break a space, so text
# from a manager cannot forge a "ts|ERROR|" line.
function Log-Write {
    param([string]$Level, [string]$Message)
    $Message = ($Message -replace '\|', '/') -replace '\r?\n|\r', ' '
    $timestamp = Log-Timestamp
    if ($null -ne $script:LOG_BUFFER) { $script:LOG_BUFFER.Add("$timestamp|$Level|$Message"); return }
    Log-Append-Raw "$timestamp|$Level|$Message"
}

# Append one already formatted line to the log file, errors ignored.
function Log-Append-Raw {
    param([string]$Line)
    try { Add-Content -LiteralPath $script:EMERGER_LOG -Value $Line -ErrorAction Stop } catch {}
}
# Log $Message at INFO, WARN or ERROR level.
function Log-Info  { param([string]$Message) Log-Write 'INFO'  $Message }
function Log-Warn  { param([string]$Message) Log-Write 'WARN'  $Message }
function Log-Error { param([string]$Message) Log-Write 'ERROR' $Message }

# Print the last 30 ERROR lines of the log and their count (--errors).
function Log-Show-Errors {
    $log = Join-Path $script:EMERGER_STATE 'emerger.log'
    if (-not (Test-Path -LiteralPath $log)) { UI-Ok 'No log yet.'; return }
    $errorLines = @(Select-String -LiteralPath $log -Pattern '\|ERROR\|' -ErrorAction SilentlyContinue)
    if ($errorLines.Count -eq 0) { UI-Ok 'No errors logged.'; return }
    UI-Warn "$($errorLines.Count) error line(s) in ${log}:"
    $errorLines | Select-Object -Last 30 | ForEach-Object { Write-Host ("  " + ($_.Line -replace '\|ERROR\|', ('|' + (UI-Color red 'ERROR') + '|'))) }
}
