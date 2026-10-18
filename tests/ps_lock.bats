#!/usr/bin/env bats
# PowerShell per-user run lock, run through pwsh where it is installed.

load ps_helper

@test "ps: a second run while another holds the per-user run lock is refused with exit 1" {
    hold_lock
    run up_ps '' -n -nc -nt
    kill "$(cat "$HOME/holder")" 2>/dev/null; wait "$(cat "$HOME/holder")" 2>/dev/null || true
    [ -e "$HOME/held" ]
    [ "$status" -eq 1 ]
    [[ "$output" == *"Another eMerger run is in progress"* ]]
    run up_ps '' -n -nc -nt
    [ "$status" -eq 0 ]
}

@test "ps: -up, -au, -rc and --reboot wait for the run lock like a run" {
    mkdir -p "$HOME/bin" "$LOCALAPPDATA/emerger/cache"
    printf '#!/bin/sh\necho "git $*" >>"%s/trace"\n' "$HOME" >"$HOME/bin/git"; chmod +x "$HOME/bin/git"
    touch "$LOCALAPPDATA/emerger/cache/keep"
    hold_lock
    local f out=""
    for f in -up -au -rc --reboot; do
        run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_ps); up_ps 'function Register-ScheduledTask { New-Item -ItemType File \"\$env:HOME/task\" | Out-Null }' $f"
        out+="$f=$status;"
        [[ "$output" == *"Another eMerger run is in progress"* ]] || out+="$f-no-message;"
    done
    kill "$(cat "$HOME/holder")" 2>/dev/null; wait "$(cat "$HOME/holder")" 2>/dev/null || true
    [ -e "$HOME/held" ]
    [ "$out" = "-up=1;-au=1;-rc=1;--reboot=1;" ]
    [ ! -e "$HOME/trace" ]
    [ ! -e "$HOME/task" ]
    [ -e "$LOCALAPPDATA/emerger/cache/keep" ]
}

@test "ps: a run lock the run may not open stops the run with the reason" {
    run ps "\$script:EMERGER_STATE = '$HOME'
        \$l = Lock-Acquire
        \"held=\$(\$null -ne \$l)\"
        Lock-Release \$l"
    [ "$status" -eq 0 ]
    [ "$output" = "held=True" ]
    mkdir -p "$LOCALAPPDATA/emerger/state/run.lock"
    run up_ps '' -n -nc -nt
    [ "$status" -eq 1 ]
    [[ "$output" == *"Cannot open the run lock"*"run.lock"* ]]
    [[ "$output" != *"Another eMerger run is in progress"* ]]
}

@test "ps: a run lock name squatted in the shared mutex namespace does not block the run" {
    pwsh -NoProfile -NonInteractive -Command "
        \$m = [Threading.Mutex]::new(\$false, \"Global\\eMerger-\$([Environment]::UserName)\")
        [void]\$m.WaitOne(0)
        New-Item -ItemType File '$HOME/held' | Out-Null
        Start-Sleep 30" >/dev/null 2>&1 &
    local holder=$! n=0
    while [ ! -e "$HOME/held" ] && [ "$n" -lt 100 ]; do sleep 0.1; n=$((n + 1)); done
    run up_ps '' -n -nc -nt
    kill "$holder" 2>/dev/null; wait "$holder" 2>/dev/null || true
    [ -e "$HOME/held" ]
    [ "$status" -eq 0 ]
    [[ "$output" != *"Another eMerger run is in progress"* ]]
}

@test "ps: a run is refused while an elevated child of an interrupted run still holds its lock" {
    hold_lock elevated.lock
    run up_ps '' -n -nc -nt
    kill "$(cat "$HOME/holder")" 2>/dev/null; wait "$(cat "$HOME/holder")" 2>/dev/null || true
    [ -e "$HOME/held" ]
    [ "$status" -eq 1 ]
    [[ "$output" == *"Another eMerger run is in progress"* ]]
    run up_ps '' -n -nc -nt
    [ "$status" -eq 0 ]
}

@test "ps: Lock-Open takes the file exclusively, a second open of a held lock gets null" {
    run ps '. (Join-Path $env:PSLIB "state/Lock.ps1")
        $path = Join-Path $env:HOME "x.lock"
        $first = Lock-Open $path
        $second = Lock-Open $path
        "first=$($null -ne $first) second=$($null -ne $second)"
        Lock-Release $first
        $third = Lock-Open $path
        "after release=$($null -ne $third)"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"first=True second=False"* ]]
    [[ "$output" == *"after release=True"* ]]
}
