#!/usr/bin/env bats
# PowerShell platform checks: reboot, weather, battery, run through pwsh where it is installed.

load ps_helper

@test "ps: --dry-run with --reboot and a pending reboot does not restart" {
    mkdir -p "$HOME/hklm/SOFTWARE/Microsoft/Windows/CurrentVersion/Component Based Servicing/RebootPending"
    run up_ps "function Restart-Computer { New-Item -ItemType File '$HOME/rebooted' | Out-Null }" -n --reboot
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/rebooted" ]
    [[ "$output" == *"[dry-run] would reboot"* ]]
}

@test "ps: --reboot with a pending reboot restarts outside dry-run" {
    mkdir -p "$HOME/hklm/SOFTWARE/Microsoft/Windows/CurrentVersion/Component Based Servicing/RebootPending"
    run up_ps "function Restart-Computer { New-Item -ItemType File '$HOME/rebooted' | Out-Null }" --reboot
    [ "$status" -eq 0 ]
    [ -e "$HOME/rebooted" ]
}

@test "ps: -w and --weather print the wttr.in line with control characters stripped" {
    local stub="function Invoke-WebRequest {
        param(\$Uri, \$TimeoutSec, [switch]\$UseBasicParsing)
        Add-Content '$HOME/fetched' \"\$Uri|\$TimeoutSec\"
        [pscustomobject]@{ Content = \"Milan: \$([char]27)[31mSun\$([char]27)[0m +20C\$([char]7)\$([char]27)]0;title\$([char]7)\`nend\" }
    }"
    run up_ps "$stub" -n -nc -nt -w
    [ "$status" -eq 0 ]
    [[ "$output" == *"Milan: Sun +20C end"* ]]
    [[ "$output" != *$'\e'* ]]
    [[ "$output" != *$'\a'* ]]
    [[ "$output" != *title* ]]
    [ "$(cat "$HOME/fetched")" = "https://wttr.in/?format=%l:+%c+%t+%w+%m|3" ]
    run up_ps "$stub" -ynw -nc -nt
    [ "$status" -eq 0 ]
    [[ "$output" == *"Milan: Sun +20C end"* ]]
    rm -f "$HOME/fetched"
    run up_ps "$stub" -n -nc -nt
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/fetched" ]
    run up_ps "function Invoke-WebRequest { throw 'offline' }" -n -nc -nt --weather
    [ "$status" -eq 0 ]
    [[ "$output" != *offline* ]]
}

@test "ps: battery percent with two batteries is their average" {
    run ps 'function Get-CimInstance { @([pscustomobject]@{ EstimatedChargeRemaining = 10; BatteryStatus = 1 },
                                         [pscustomobject]@{ EstimatedChargeRemaining = 25; BatteryStatus = 2 }) }
        Preflight-Battery-Percent
        Preflight-Is-On-Battery
        function Get-CimInstance { [pscustomobject]@{ EstimatedChargeRemaining = 42; BatteryStatus = 2 } }
        Preflight-Battery-Percent
        Preflight-Is-On-Battery'
    [ "$status" -eq 0 ]
    [ "$output" = $'17\nTrue\n42\nFalse' ]
}

@test "ps: declining the low-battery prompt aborts with exit 1" {
    run up_ps 'function Get-CimInstance { [pscustomobject]@{ EstimatedChargeRemaining = 5; BatteryStatus = 1 } }' -nc -nt </dev/null
    [ "$status" -eq 1 ]
    [[ "$output" == *"Aborted"* ]]
}

@test "ps: log and history are written and read when the state path holds wildcard brackets" {
    run ps '. (Join-Path $env:PSLIB "state/History.ps1")
        $script:EMERGER_STATE = Join-Path $env:HOME "A[1]/state"
        Log-Init
        Log-Error "boom"
        History-Append "{`"ts`":`"t`",`"duration`":1,`"errors`":1}"
        "log lines: $((Get-Content -LiteralPath $script:EMERGER_LOG | Measure-Object).Count)"
        "history lines: $((Get-Content -LiteralPath (Join-Path $script:EMERGER_STATE "history.jsonl") | Measure-Object).Count)"
        Log-Show-Errors'
    [ "$status" -eq 0 ]
    [[ "$output" == *"log lines: 1"* ]]
    [[ "$output" == *"history lines: 1"* ]]
    [[ "$output" == *"1 error line(s)"* ]]
}
