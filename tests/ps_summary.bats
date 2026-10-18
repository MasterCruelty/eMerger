#!/usr/bin/env bats
# PowerShell summary, history and log, run through pwsh where it is installed.

load ps_helper

# Get-Content that keeps the file open while it emits, and Set-Content that
# fails on a file still open for reading, as Windows PowerShell 5.1 does.
SHARING_STUBS='
    function Get-Content { $global:READING = $true; try { Microsoft.PowerShell.Management\Get-Content @args } finally { $global:READING = $false } }
    function Set-Content {
        param([Parameter(Position = 0)][Alias("LiteralPath")]$Path, [Parameter(ValueFromPipeline = $true)]$Value)
        begin { $all = @() }
        process { if ($global:READING) { throw "The process cannot access the file because it is being used by another process." }; $all += $Value }
        end { Microsoft.PowerShell.Management\Set-Content -LiteralPath $Path -Value $all }
    }'

@test "ps: log and history rotation finish reading before they rewrite the file" {
    mkdir -p "$LOCALAPPDATA/emerger/state"
    seq 1 2500 >"$LOCALAPPDATA/emerger/state/emerger.log"
    seq 1 600 | sed 's/.*/{"ts":"2026-01-01T00:00:00Z","n":&}/' >"$LOCALAPPDATA/emerger/state/history.jsonl"
    run ps ". (Join-Path \$env:PSLIB 'Summary.ps1'); . (Join-Path \$env:PSLIB 'state/History.ps1'); . (Join-Path \$env:PSLIB 'system/Reboot.ps1')
        $SHARING_STUBS
        Log-Init
        \$script:Summary = @()
        History-Append (Summary-Json 1)
        'rotated'"
    [ "$status" -eq 0 ]
    [[ "$output" == *rotated* ]]
    [ "$(wc -l <"$LOCALAPPDATA/emerger/state/emerger.log")" -eq 2000 ]
    [ "$(head -1 "$LOCALAPPDATA/emerger/state/emerger.log")" = 501 ]
    [ "$(wc -l <"$LOCALAPPDATA/emerger/state/history.jsonl")" -eq 500 ]
    [[ "$(tail -1 "$LOCALAPPDATA/emerger/state/history.jsonl")" == *'"duration":1'* ]]
}

@test "ps: elapsed seconds are truncated, not rounded" {
    run ps '$t0 = [DateTime]::new(2026, 1, 1, 0, 0, 0, [DateTimeKind]::Utc)
        Sys-Elapsed-Seconds $t0 $t0.AddMilliseconds(1900)
        Sys-Elapsed-Seconds $t0 $t0.AddSeconds(61.5)
        Sys-Elapsed-Seconds $t0 $t0'
    [ "$status" -eq 0 ]
    [ "$output" = $'1\n61\n0' ]
}

@test "ps: log and history timestamps use colons whatever the culture's time separator" {
    mkdir -p "$LOCALAPPDATA/emerger/state"
    run ps ". (Join-Path \$env:PSLIB 'Summary.ps1'); . (Join-Path \$env:PSLIB 'state/History.ps1'); . (Join-Path \$env:PSLIB 'system/Reboot.ps1')
        \$c = [Globalization.CultureInfo]::new('en-US'); \$c.DateTimeFormat.TimeSeparator = '.'
        [Threading.Thread]::CurrentThread.CurrentCulture = \$c
        Log-Init; Log-Info 'x'
        \$script:Summary = @(); \$script:ArgsGlobal.Json = \$true
        Summary-Print 3"
    [ "$status" -eq 0 ]
    [[ "$output" =~ \"ts\":\"[0-9-]+T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\" ]]
    grep -Eq '^[0-9-]+T[0-9]{2}:[0-9]{2}:[0-9]{2}Z\|INFO\|x$' "$LOCALAPPDATA/emerger/state/emerger.log"
    grep -Eq '"ts":"[0-9-]+T[0-9]{2}:[0-9]{2}:[0-9]{2}Z"' "$LOCALAPPDATA/emerger/state/history.jsonl"
}

@test "ps: -qq still prints the reboot advisory" {
    mkdir -p "$LOCALAPPDATA/emerger/state" "$HOME/hklm/SOFTWARE/Microsoft/Windows/CurrentVersion/Component Based Servicing/RebootPending"
    run ps "New-PSDrive -Name HKLM -PSProvider FileSystem -Root '$HOME/hklm' | Out-Null
        . (Join-Path \$env:PSLIB 'Summary.ps1'); . (Join-Path \$env:PSLIB 'state/History.ps1'); . (Join-Path \$env:PSLIB 'system/Reboot.ps1')
        \$script:Summary = @([pscustomobject]@{ Name = 'winget'; Result = 'ok'; Secs = 1 })
        \$script:QUIET_LEVEL = 2
        Summary-Print 3"
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 managers ok, 0m03s"* ]]
    [[ "$output" == *"Reboot recommended"* ]]
}

@test "ps: the time estimate rounds a half-second average up" {
    mkdir -p "$LOCALAPPDATA/emerger/state"
    printf '{"managers":[{"name":"winget","secs":2}]}\n{"managers":[{"name":"winget","secs":3}]}\n{"managers":[{"name":"scoop","secs":0}]}\n' >"$LOCALAPPDATA/emerger/state/history.jsonl"
    run ps '"[$(Estimate-Read winget)][$(Estimate-Read scoop)]"'
    [ "$status" -eq 0 ]
    [ "$output" = "[~3s][]" ]
}

@test "ps: a dry run writes no history line and a real run writes one at every quiet level" {
    mkdir -p "$HOME/bin"
    printf '#!/bin/sh\n' >"$HOME/bin/scoop"; chmod +x "$HOME/bin/scoop"
    local hist="$LOCALAPPDATA/emerger/state/history.jsonl" q n=0
    for q in -q -qq -qqq --json; do
        run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_ps); up_ps '' -n -y -nc -nt $q"
        [ "$status" -eq 0 ]
        [ ! -e "$hist" ] || { echo "dry run $q wrote history"; return 1; }
    done
    for q in -q -qq -qqq --json; do
        run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_ps); up_ps '' -y -nc -nt $q"
        [ "$status" -eq 0 ]
        n=$((n + 1))
        [ "$(wc -l <"$hist")" -eq "$n" ] || { echo "real run $q: $(wc -l <"$hist") lines"; return 1; }
    done
}

@test "ps: the --json line is the history line, with per-manager secs" {
    mkdir -p "$HOME/bin"
    printf '#!/bin/sh\n' >"$HOME/bin/scoop"; chmod +x "$HOME/bin/scoop"
    run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_ps); up_ps '' -y -nc -nt --json 2>/dev/null"
    [ "$status" -eq 0 ]
    [ "${#lines[@]}" -eq 1 ]
    [[ "${lines[0]}" == *'"managers":[{"name":"scoop","result":"ok","secs":'[0-9]*'}]}' ]]
    [ "${lines[0]}" = "$(cat "$LOCALAPPDATA/emerger/state/history.jsonl")" ]
}

@test "ps: a run's freed space goes to history.jsonl as freed_kb in KiB" {
    run ps '. (Join-Path $env:PSLIB "clean/Size.ps1"); . (Join-Path $env:PSLIB "Summary.ps1")
        $script:SUMMARY_FREED_KB = 2048
        function Reboot-Pending { $false }
        (Summary-Json 1 | ConvertFrom-Json).freed_kb
        Size-Format-KB 2048; Size-Format-KB 1572864'
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = 2048 ]
    [ "${lines[1]}" = 2.0MB ]
    [ "${lines[2]}" = 1.5GB ]
}

@test "ps: --errors and --history with nothing recorded print the Unix messages" {
    run ps ". (Join-Path \$env:PSLIB 'state/History.ps1'); \$script:QUIET_LEVEL = 0; Log-Show-Errors; History-Show"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No log yet."* ]]
    [[ "$output" == *"No history yet."* ]]
    mkdir -p "$LOCALAPPDATA/emerger/state"
    echo "2026-01-01T00:00:00Z|INFO|x" >"$LOCALAPPDATA/emerger/state/emerger.log"
    run ps "Log-Show-Errors"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No errors logged."* ]]
}
