# Step duration estimate from recent history.jsonl entries.

# Read the average duration of manager $Manager over the last 10 runs from
# history.jsonl as "~42s", for the section header. Return '' without data.
function Estimate-Read {
    param([string]$Manager)
    $historyPath = Join-Path $script:EMERGER_STATE 'history.jsonl'
    if (-not (Test-Path -LiteralPath $historyPath)) { return '' }
    $seconds = @()
    foreach ($line in (Get-Content -LiteralPath $historyPath -Tail 10 -ErrorAction SilentlyContinue)) {
        try {
            $record = $line | ConvertFrom-Json
            foreach ($entry in $record.managers) { if ($entry.name -eq $Manager -and $entry.secs -gt 0) { $seconds += [double]$entry.secs } }
        } catch {}
    }
    if ($seconds.Count -eq 0) { return '' }
    # Round half up: an [int] cast rounds a .5 to even.
    $average = [int][math]::Round(($seconds | Measure-Object -Average).Average, [MidpointRounding]::AwayFromZero)
    if ($average -lt 60) { return "~${average}s" }
    return ('~{0}m{1:00}s' -f [int][math]::Floor($average / 60), ($average % 60))
}
