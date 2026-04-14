# Structured logging to $EMERGER_LOG.

function Log-Init {
    $script:EMERGER_LOG = Join-Path $script:EMERGER_STATE 'emerger.log'
    if (-not (Test-Path $script:EMERGER_STATE)) {
        New-Item -ItemType Directory -Path $script:EMERGER_STATE -Force | Out-Null
    }
    if (-not (Test-Path $script:EMERGER_LOG)) {
        New-Item -ItemType File -Path $script:EMERGER_LOG -Force | Out-Null
    }
    # Rotate at 2000 lines.
    $count = (Get-Content $script:EMERGER_LOG -ErrorAction SilentlyContinue | Measure-Object).Count
    if ($count -gt 2000) {
        Get-Content $script:EMERGER_LOG -Tail 2000 | Set-Content $script:EMERGER_LOG
    }
}

function Log-Write {
    param([string]$Level, [string]$Msg)
    $ts = (Get-Date).ToUniversalTime().ToString('yyyy-MM-ddTHH:mm:ssZ')
    try { Add-Content -Path $script:EMERGER_LOG -Value "$ts|$Level|$Msg" -ErrorAction Stop } catch {}
}
function Log-Info  { param([string]$M) Log-Write 'INFO'  $M }
function Log-Warn  { param([string]$M) Log-Write 'WARN'  $M }
function Log-Error { param([string]$M) Log-Write 'ERROR' $M }
