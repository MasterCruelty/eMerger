#!/usr/bin/env bats
# PowerShell self-update and the scheduled task, run through pwsh where it is installed.

load ps_helper

@test "ps: self-update stops with its own message when git fetch fails" {
    mkdir -p "$HOME/bin" "$HOME/root/.git"
    printf '#!/bin/sh\ncase "$3" in\n  rev-parse) echo 0123456789abcdef ;;\n  fetch) echo "fatal: unable to access" >&2; exit 1 ;;\n  pull) echo pulled >>"%s/trace" ;;\nesac\nexit 0\n' "$HOME" >"$HOME/bin/git"
    chmod +x "$HOME/bin/git"
    run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f ps); ps \"\$1\"" _ ". (Join-Path \$env:PSLIB 'SelfUpdate.ps1')
        \$PSNativeCommandUseErrorActionPreference = \$true
        \$rc = SelfUpdate-Run '$HOME/root'
        \"rc=\$rc\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"git fetch failed"* ]]
    [[ "$output" == *"rc=1"* ]]
    [[ "$output" != *NativeCommand* ]]
    [ ! -e "$HOME/trace" ]
}

@test "ps: the scheduled task starts the PowerShell host that registered it" {
    run ps ". (Join-Path \$env:PSLIB 'AutoUpdate.ps1')
        function New-ScheduledTaskAction { param(\$Execute, \$Argument) Set-Content '$HOME/task' \"\$Execute|\$Argument\"; 'action' }
        function New-ScheduledTaskTrigger { 'trigger' }
        function New-ScheduledTaskSettingsSet { 'settings' }
        function New-ScheduledTaskPrincipal { 'principal' }
        function Register-ScheduledTask { }
        \$rc = AutoUpdate-Register '/opt/e M'
        \"rc=\$rc host=\$((Get-Process -Id \$PID).Path)\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"rc=0"* ]]
    local host="${output##*host=}"
    [ "$(cut -d'|' -f1 "$HOME/task")" = "$host" ]
    [[ "$(cut -d'|' -f2 "$HOME/task")" == *'-File "/opt/e M'*'emerger.ps1" -y -q -nl -ni' ]]
}
