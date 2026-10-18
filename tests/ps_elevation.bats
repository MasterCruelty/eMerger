#!/usr/bin/env bats
# PowerShell elevated child for the admin managers, run through pwsh where it is installed.

load ps_helper

@test "ps: only the admin managers run elevated, config and hooks stay in the caller" {
    elevation_stubs
    run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_ps); up_ps \"\$1\" -y -nc -nt --accept-licenses" _ "$START_PROCESS_STUB"
    [ "$status" -eq 0 ]
    grep -qx 'start verb=RunAs' "$HOME/trace"
    grep -qx 'choco elevated=1' "$HOME/trace"
    [ "$(grep -c '^config' "$HOME/trace")" -eq 1 ]
    grep -qx 'config elevated=0' "$HOME/trace"
    [ "$(grep -c '^hook' "$HOME/trace")" -eq 1 ]
    grep -qx 'hook elevated=0' "$HOME/trace"
    [[ "$output" == *"choco upgrade all"*"1 upgraded"* ]]
    grep -q '|INFO|starting choco' "$LOCALAPPDATA/emerger/state/emerger.log"
}

@test "ps: the elevated child refuses a non-admin manager and a pre-existing result path" {
    run pwsh -NoProfile -NonInteractive -File "$REPO_DIR/src/emerger.ps1" --elevated-child "$HOME/$RESULT_LEAF" scoop 2 3 0 0
    [ "$status" -eq 2 ]
    [ ! -e "$HOME/$RESULT_LEAF" ]
    run pwsh -NoProfile -NonInteractive -File "$REPO_DIR/src/emerger.ps1" --elevated-child "$HOME/$RESULT_LEAF" choco 2 3 0 0 '-y;x'
    [ "$status" -eq 2 ]
    elevation_stubs
    echo original >"$HOME/victim"
    ln -s "$HOME/victim" "$HOME/$RESULT_LEAF"
    run env PATH="$HOME/bin:$PATH" pwsh -NoProfile -NonInteractive -File "$REPO_DIR/src/emerger.ps1" --elevated-child "$HOME/$RESULT_LEAF" choco 2 3 0 0 -y
    [ "$status" -eq 1 ]
    [ "$(cat "$HOME/victim")" = original ]
    ! grep -q '^config' "$HOME/trace"
}

@test "ps: a failing elevated manager gives exit 3 and --json on the caller's stdout" {
    elevation_stubs
    run env PATH="$HOME/bin:$PATH" CHOCO_RC=1 bash -c "$(declare -f up_ps); up_ps \"\$1\" -y -nc -nt --json 2>/dev/null" _ "$START_PROCESS_STUB"
    [ "$status" -eq 3 ]
    grep -qx 'choco elevated=1' "$HOME/trace"
    [[ "$output" == *'"managers":[{"name":"choco","result":"fail","secs":'[0-9]*'}]'* ]]
}

@test "ps: a declined UAC prompt fails the admin managers without a crash" {
    elevation_stubs
    run env PATH="$HOME/bin:$PATH" DECLINE_UAC=1 bash -c "$(declare -f up_ps); up_ps \"\$1\" -y -nc -nt" _ "$START_PROCESS_STUB"
    [ "$status" -eq 3 ]
    [ "$(grep -c '^choco' "$HOME/trace")" -eq 0 ]
    grep -qx 'hook elevated=0' "$HOME/trace"
    [[ "$output" == *"canceled by the user"* ]]
}

@test "ps: elevated relaunch quotes embedded quotes and trailing backslashes" {
    run ps 'function Start-Process { param($FilePath, $ArgumentList, $Verb, [switch]$Wait, [switch]$PassThru)
            Set-Content (Join-Path $env:HOME "argv") "$ArgumentList"; [pscustomobject]@{ ExitCode = 7 } }
        Elevated-Start "C:\e M\emerger.ps1" @("a`"b", "C:\dir x\", "plain")'
    [ "$status" -eq 0 ]
    [ "$output" = 7 ]
    [[ "$(cat "$HOME/argv")" == *'-File "C:\e M\emerger.ps1" "a\"b" "C:\dir x\\" plain' ]]
}

@test "ps: a result file planted before the elevated child writes is not trusted" {
    elevation_stubs
    local plant="function Start-Process {
        param(\$FilePath, \$ArgumentList, \$Verb, [switch]\$Wait, [switch]\$PassThru)
        \$file = ([regex]::Match(\$ArgumentList, '--elevated-child (\S+)')).Groups[1].Value
        Set-Content \$file '{\"managers\":[{\"name\":\"choco\",\"result\":\"ok\",\"secs\":1,\"changed\":0,\"steps\":[]}],\"log\":[]}'
        \$psi = [Diagnostics.ProcessStartInfo]::new((Get-Process -Id \$PID).Path, \$ArgumentList)
        \$psi.UseShellExecute = \$false
        \$p = [Diagnostics.Process]::Start(\$psi); \$p.WaitForExit()
        [pscustomobject]@{ ExitCode = \$p.ExitCode }
    }"
    run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_ps); up_ps \"\$1\" -y -nc -nt --json 2>/dev/null" _ "$plant"
    [ "$status" -eq 3 ]
    [[ "$output" == *'"managers":[{"name":"choco","result":"fail","secs":'[0-9]*'}]'* ]]
}

@test "ps: --accept-licenses reaches the elevated child and passes its validation" {
    run ps ". (Join-Path \$env:PSLIB 'Elevated.ps1')
        \$script:RETRY_ATTEMPTS = 2; \$script:RETRY_DELAY = 3; \$script:MANAGER_TIMEOUT = 0
        \$script:ArgsGlobal.AcceptLicenses = \$true
        (Elevated-Args '/r.json' @('PSWindowsUpdate')) -join ' '"
    [ "$status" -eq 0 ]
    [[ "$output" == *"PSWindowsUpdate 2 3 0 0 --accept-licenses" ]]
    run pwsh -NoProfile -NonInteractive -File "$REPO_DIR/src/emerger.ps1" --elevated-child "$HOME/$RESULT_LEAF" PSWindowsUpdate 2 3 0 0 --accept-licenses
    [[ "$output" != *"invalid arguments"* ]]
    [ "$status" -eq 0 ] || [ "$status" -eq 3 ]
    [ -e "$HOME/$RESULT_LEAF" ]
}

@test "ps: a negative MANAGER_TIMEOUT in config.ps1 does not fail the elevated managers" {
    elevation_stubs
    printf '$script:MANAGER_TIMEOUT = -1\n' >>"$APPDATA/emerger/config.ps1"
    run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_ps); up_ps \"\$1\" -y -nc -nt" _ "$START_PROCESS_STUB"
    [ "$status" -eq 0 ]
    grep -qx 'choco elevated=1' "$HOME/trace"
    [[ "$output" != *"invalid arguments"* ]]
}

@test "ps: the elevated child holds the elevated lock while its managers run" {
    elevation_stubs
    mkdir -p "$LOCALAPPDATA/emerger/state"
    printf '#!/bin/sh\nif flock -n "%s" true; then echo "lock free" >>"%s/trace"; else echo "lock held" >>"%s/trace"; fi\n' \
        "$LOCALAPPDATA/emerger/state/elevated.lock" "$HOME" "$HOME" >"$HOME/bin/choco"
    run env PATH="$HOME/bin:$PATH" pwsh -NoProfile -NonInteractive -File "$REPO_DIR/src/emerger.ps1" --elevated-child "$HOME/$RESULT_LEAF" choco 2 3 0 0
    [ "$status" -eq 0 ]
    grep -qx 'lock held' "$HOME/trace"
}

@test "ps: the elevated child refuses a result path off the local disk or with a foreign name" {
    elevation_stubs
    run env PATH="$HOME/bin:$PATH" pwsh -NoProfile -NonInteractive -File "$REPO_DIR/src/emerger.ps1" --elevated-child "//srv/share/$RESULT_LEAF" choco 2 3 0 0
    [ "$status" -eq 2 ]
    [[ "$output" == *"invalid arguments"* ]]
    run env PATH="$HOME/bin:$PATH" pwsh -NoProfile -NonInteractive -File "$REPO_DIR/src/emerger.ps1" --elevated-child "$HOME/r.json" choco 2 3 0 0
    [ "$status" -eq 2 ]
    [ ! -e "$HOME/r.json" ]
    [ ! -e "$HOME/trace" ] || ! grep -q '^choco' "$HOME/trace"
}

@test "ps: the elevated child drops user PATH and PSModulePath entries and keeps the system ones" {
    export SystemRoot="$HOME/Windows" ProgramData="$HOME/ProgramData" ProgramFiles="$HOME/PF"
    run pwsh -NoProfile -NonInteractive -Command "
        \$env:PATH = '$HOME/evil' + [IO.Path]::PathSeparator + \$env:PATH
        \$env:PSModulePath = '$HOME/mods' + [IO.Path]::PathSeparator + \$env:PSModulePath
        . '$PSLIB/Elevated.ps1'
        Elevated-Restrict-Env
        \"path=\$env:PATH\"
        \"mods=\$env:PSModulePath\""
    [ "$status" -eq 0 ]
    [[ "$output" != *"$HOME/evil"* ]]
    [[ "$output" != *"$HOME/mods"* ]]
    [[ "$output" == *"path="*"$HOME/Windows"* ]]
    [[ "$output" == *"$HOME/ProgramData/chocolatey"*"bin"* ]]
    [[ "$output" == *"mods="*"$HOME/PF"*"Modules"* ]]
}

@test "ps: an elevated manager planted in a user PATH directory is not run by the child" {
    mkdir -p "$HOME/evil" "$HOME/ProgramData/chocolatey"
    printf '#!/bin/sh\necho ran >"%s/marker"\nexit 0\n' "$HOME" >"$HOME/evil/choco"
    chmod +x "$HOME/evil/choco"
    elevation_stubs
    rm -f "$HOME/bin/choco"; rm -rf "$HOME/ProgramData/chocolatey/bin"; mkdir -p "$HOME/ProgramData/chocolatey/bin"
    run env PATH="$HOME/evil:$PATH" bash -c "$(declare -f up_ps); up_ps \"\$1\" -y -nc -nt" _ "$START_PROCESS_STUB"
    [ ! -e "$HOME/marker" ]
}

@test "ps: the elevated child holds the lock even without a state directory" {
    elevation_stubs
    printf '#!/bin/sh\nif [ -e "%s" ] && ! flock -n "%s" true; then echo "lock held" >>"%s/trace"; else echo "lock free" >>"%s/trace"; fi\n' \
        "$LOCALAPPDATA/emerger/state/elevated.lock" "$LOCALAPPDATA/emerger/state/elevated.lock" "$HOME" "$HOME" >"$HOME/bin/choco"
    [ ! -e "$LOCALAPPDATA/emerger/state" ]
    run env PATH="$HOME/bin:$PATH" pwsh -NoProfile -NonInteractive -File "$REPO_DIR/src/emerger.ps1" --elevated-child "$HOME/$RESULT_LEAF" choco 2 3 0 0
    [ "$status" -eq 0 ]
    grep -qx 'lock held' "$HOME/trace"
}

@test "ps: the elevated child refuses to run its managers when it cannot open the lock" {
    elevation_stubs
    mkdir -p "$LOCALAPPDATA/emerger/state/elevated.lock"
    run env PATH="$HOME/bin:$PATH" pwsh -NoProfile -NonInteractive -File "$REPO_DIR/src/emerger.ps1" --elevated-child "$HOME/$RESULT_LEAF" choco 2 3 0 0
    [ "$status" -eq 1 ]
    [[ "$output" == *"cannot take the elevated lock"* ]]
    [ ! -e "$HOME/trace" ] || ! grep -q '^choco' "$HOME/trace"
}

@test "ps: the elevated child refuses a relative result path and a known flag outside its allowlist" {
    elevation_stubs
    cd "$HOME"
    run env PATH="$HOME/bin:$PATH" pwsh -NoProfile -NonInteractive -File "$REPO_DIR/src/emerger.ps1" --elevated-child "$RESULT_LEAF" choco 2 3 0 0
    [ "$status" -eq 2 ]
    [[ "$output" == *"elevated child: invalid arguments"* ]]
    [ ! -e "$RESULT_LEAF" ]
    run env PATH="$HOME/bin:$PATH" pwsh -NoProfile -NonInteractive -File "$REPO_DIR/src/emerger.ps1" --elevated-child "$HOME/$RESULT_LEAF" choco 2 3 0 0 --dev
    [ "$status" -eq 2 ]
    [[ "$output" == *"elevated child: invalid arguments: --dev"* ]]
    [ ! -e "$HOME/trace" ] || ! grep -q '^choco' "$HOME/trace"
}

@test "ps: the elevated child resets environment variables that steer what runs as administrator" {
    export SystemRoot="$HOME/Windows" ProgramData="$HOME/ProgramData" ProgramFiles="$HOME/PF"
    run pwsh -NoProfile -NonInteractive -Command "
        foreach (\$n in 'DOTNET_STARTUP_HOOKS','COR_ENABLE_PROFILING','COR_PROFILER','COR_PROFILER_PATH','COR_PROFILER_PATH_64','CORECLR_ENABLE_PROFILING','CORECLR_PROFILER_PATH','DOTNET_ADDITIONAL_DEPS','COMPlus_EnableDiagnostics','PSExecutionPolicyPreference','ChocolateyInstall') { Set-Item \"env:\$n\" '$HOME/evil' }
        \$env:ComSpec = '$HOME/evil/cmd'
        \$env:PATHEXT = '.EVIL'
        . '$PSLIB/Elevated.ps1'
        Elevated-Restrict-Env
        foreach (\$n in 'DOTNET_STARTUP_HOOKS','COR_ENABLE_PROFILING','COR_PROFILER','COR_PROFILER_PATH','COR_PROFILER_PATH_64','CORECLR_ENABLE_PROFILING','CORECLR_PROFILER_PATH','DOTNET_ADDITIONAL_DEPS','COMPlus_EnableDiagnostics','PSExecutionPolicyPreference','ChocolateyInstall') { \"\$n=[\$((Get-Item \"env:\$n\" -ErrorAction SilentlyContinue).Value)]\" }
        \"ComSpec=\$env:ComSpec\"
        \"PATHEXT=\$env:PATHEXT\""
    [ "$status" -eq 0 ]
    [[ "$output" != *"$HOME/evil"* ]]
    [[ "$output" != *".EVIL"* ]]
    [[ "$output" == *"DOTNET_STARTUP_HOOKS=[]"* ]]
    [[ "$output" == *"COR_PROFILER_PATH_64=[]"* ]]
    [[ "$output" == *"ChocolateyInstall=[]"* ]]
    [[ "$output" == *"ComSpec=$HOME/Windows/System32/cmd.exe"* ]]
}

@test "ps: the child keeps the machine-scope ChocolateyInstall and ignores the caller's" {
    export SystemRoot="$HOME/Windows" ProgramData="$HOME/ProgramData" ProgramFiles="$HOME/PF"
    run pwsh -NoProfile -NonInteractive -Command "
        \$env:ChocolateyInstall = '$HOME/evil'
        . '$PSLIB/Elevated.ps1'
        function _Elevated-Machine-Env { param([string]\$Name) if (\$Name -eq 'ChocolateyInstall') { return '$HOME/ProgramData/chocolatey' } }
        Elevated-Restrict-Env
        \"choco=\$env:ChocolateyInstall\""
    [[ "$output" == *"choco=$HOME/ProgramData/chocolatey"* ]]
    [[ "$output" != *"evil"* ]]
}

@test "ps: a choco.exe planted outside the admin-only locations is refused, one under Program Files is accepted" {
    export SystemRoot="$HOME/Windows" ProgramData="$HOME/ProgramData" ProgramFiles="$HOME/PF"
    mkdir -p "$HOME/evil" "$HOME/PF/app"
    printf '#!/bin/sh\nexit 0\n' >"$HOME/evil/choco"; chmod +x "$HOME/evil/choco"
    cp "$HOME/evil/choco" "$HOME/PF/app/choco"
    run pwsh -NoProfile -NonInteractive -Command "
        . '$PSLIB/Elevated.ps1'
        \$env:PATH = '$HOME/evil'
        \"planted=[\$(Elevated-Exe-Refusal choco)]\"
        \$env:PATH = '$HOME/PF/app'
        \"trusted=[\$(Elevated-Exe-Refusal choco)]\"
        \$env:PATH = '$HOME/nowhere'
        \"absent=[\$(Elevated-Exe-Refusal choco)]\""
    [[ "$output" == *"planted=[choco is outside the administrator-only locations"* ]]
    [[ "$output" == *"trusted=[]"* ]]
    [[ "$output" == *"absent=[]"* ]]
}

@test "ps: a choco under ProgramData that standard users can write is refused" {
    export SystemRoot="$HOME/Windows" ProgramData="$HOME/ProgramData" ProgramFiles="$HOME/PF"
    run pwsh -NoProfile -NonInteractive -Command "
        . '$PSLIB/Elevated.ps1'
        function _Elevated-Users-Can-Write { param([string]\$Path) return \$true }
        \$env:PATH = '$HOME/ProgramData/chocolatey/bin'
        New-Item -ItemType Directory -Force '$HOME/ProgramData/chocolatey/bin' | Out-Null
        Set-Content '$HOME/ProgramData/chocolatey/bin/choco' x
        \"open=[\$(Elevated-Exe-Refusal choco)]\"
        function _Elevated-Users-Can-Write { param([string]\$Path) return \$false }
        \"closed=[\$(Elevated-Exe-Refusal choco)]\""
    [[ "$output" == *"open=[choco is outside"* ]]
    [[ "$output" == *"closed=[]"* ]]
}

@test "ps: the elevated child fails a manager whose executable is refused and never runs it" {
    printf '#!/bin/sh\necho ran >"%s/marker"\n' "$HOME" >"$HOME/choco"; chmod +x "$HOME/choco"
    run ps '. (Join-Path $env:PSLIB "Hooks.ps1")
        function Elevated-Exe-Refusal { param([string]$Manager) return "$Manager is outside the administrator-only locations" }
        function Pkg-Run { param([string]$Manager) Set-Content (Join-Path $env:HOME "marker") ran; return $true }
        $script:LOG_BUFFER = New-Object System.Collections.Generic.List[string]
        $file = Join-Path $env:HOME "emerger-0123456789abcdef0123456789abcdef.json"
        "rc=$(_Elevated-Child-Run $file @("choco"))"'
    [[ "$output" == *"rc=3"* ]]
    [ ! -e "$HOME/marker" ]
    grep -q 'outside the administrator-only' "$HOME/emerger-0123456789abcdef0123456789abcdef.json"
}
