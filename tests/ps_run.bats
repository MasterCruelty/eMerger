#!/usr/bin/env bats
# PowerShell step runner: process, output parsing, timeout, interrupt, run through pwsh where it is installed.

load ps_helper

@test "ps: progress parsers ignore counters too big for an int" {
    run ps '
        $n = "12345678901"
        foreach ($c in @(@("winget", "$n upgrades available."), @("winget", "($n/$n) Found X [x.y]"),
                         @("choco", "Chocolatey upgraded $n/$n packages."), @("scoop", "Updating $n outdated apps:"),
                         @("PSWindowsUpdate", "Accepted [$n] Updates"), @("PSWindowsUpdate", "Found [$n] Updates in post search"),
                         @("pip", "[$n/$n] pkg"), @("npm", "($n/$n) done"))) {
            Progress-Reset $c[0] 0
            [void](Progress-Feed $c[1])
            "$($c[0]) tot=$($script:PROGRESS_STATE.Total) cur=$($script:PROGRESS_STATE.Current)"
        }
        Progress-Reset winget 0; [void](Progress-Feed "3 upgrades available."); "small tot=$($script:PROGRESS_STATE.Total)"'
    [ "$status" -eq 0 ]
    [[ "$output" != *"Cannot convert"* ]]
    [ "$(grep -c 'tot=0 cur=0' <<<"$output")" -eq 8 ]
    [[ "$output" == *"small tot=3"* ]]
}

@test "ps: a parser error inside _Run-Consume does not escape to the running step" {
    run ps '
        function Progress-Feed { throw "parser broke" }
        $st = @{ Log = (New-Object System.Text.StringBuilder); Carry = "" }
        _Run-Consume $st "line one`nline two`n"
        "consumed log=$($st.Log.Length)"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"consumed log=18"* ]]
}

@test "ps: cmd.exe metacharacters in a .cmd shim path are caret-escaped" {
    mkdir -p "$HOME/A&B" "$HOME/50%x" "$HOME/C D&E" "$HOME/F G%H"
    for d in "A&B" "50%x" "C D&E" "F G%H"; do printf '@echo off\n' >"$HOME/$d/npm.cmd"; chmod +x "$HOME/$d/npm.cmd"; done
    run ps "
        \$env:ComSpec = 'cmd.exe'
        foreach (\$d in 'A&B', '50%x', 'C D&E', 'F G%H') {
            \$t = _Run-Resolve (Join-Path '$HOME' \"\$d/npm.cmd\") @('update', '-g')
            \"\$(\$t.File)|\$(\$t.Args)\"
        }"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "cmd.exe|/d /s /c \"$HOME/A^&B/npm.cmd update -g\"" ]
    [ "${lines[1]}" = "cmd.exe|/d /s /c \"$HOME/50^%x/npm.cmd update -g\"" ]
    [ "${lines[2]}" = "cmd.exe|/d /s /c \"\"$HOME/C D&E/npm.cmd\" update -g\"" ]
    [ "${lines[3]}" = "cmd.exe|/d /s /c \"\"$HOME/F G\"^%\"H/npm.cmd\" update -g\"" ]
}

@test "ps: MANAGER_TIMEOUT kills a stalled step and its children and reports a failure" {
    printf '#!/bin/sh\nsleep 60 &\necho $! >"%s/grandchild"\nwait\n' "$HOME" >"$HOME/stall"; chmod +x "$HOME/stall"
    SECONDS=0
    run ps "\$script:RETRY_ATTEMPTS = 2; \$script:RETRY_DELAY = 0; \$script:MANAGER_TIMEOUT = 1
        \$ok = Run-Cmd 'stall' -Exe '$HOME/stall'
        \"ok=\$ok\""
    local took=$SECONDS
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok=False"* ]]
    [[ "$output" == *"timed out after 1s"* ]]
    [ "$took" -lt 20 ]
    ! kill -0 "$(cat "$HOME/grandchild")" 2>/dev/null
}

@test "ps: MANAGER_TIMEOUT 0 lets a step finish" {
    printf '#!/bin/sh\nsleep 1\necho done\n' >"$HOME/slow"; chmod +x "$HOME/slow"
    run ps "\$script:MANAGER_TIMEOUT = 0; \$ok = Run-Cmd 'slow' -Exe '$HOME/slow'; \"ok=\$ok\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok=True"* ]]
}

@test "ps: MANAGER_TIMEOUT stops a stalled verbose step and fails it" {
    printf '#!/bin/sh\nsleep 60\n' >"$HOME/stall"; chmod +x "$HOME/stall"
    SECONDS=0
    run ps "\$script:UI_VERBOSE = \$true; \$script:MANAGER_TIMEOUT = 1; \$ok = Run-Cmd 'stall' -Exe '$HOME/stall'; \"ok=\$ok\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok=False"* ]]
    [ "$SECONDS" -lt 20 ]
}

@test "ps: an interrupted step kills the child's whole process tree" {
    printf '#!/bin/sh\nsleep 60 &\necho $! >"%s/grandchild"\nwait\n' "$HOME" >"$HOME/stall"; chmod +x "$HOME/stall"
    run ps "function UI-Monitor-Frame { if (Test-Path '$HOME/grandchild') { throw 'interrupted' } }
        \$script:RETRY_ATTEMPTS = 1
        \$ok = Run-Cmd 'stall' -Exe '$HOME/stall'
        \"ok=\$ok\""
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok=False"* ]]
    sleep 0.5
    ! kill -0 "$(cat "$HOME/grandchild")" 2>/dev/null
}

@test "ps: under --json hook and verbose manager output go to stderr" {
    mkdir -p "$HOME/bin" "$APPDATA/emerger/hooks/pre.d"
    printf '"hook out"; Write-Host "hook host"\n' >"$APPDATA/emerger/hooks/pre.d/h.ps1"
    printf '#!/bin/sh\necho "npm out"\n' >"$HOME/bin/npm"; chmod +x "$HOME/bin/npm"
    local t
    for t in 0 30; do
        printf '$script:MANAGER_TIMEOUT = %s\n' "$t" >"$APPDATA/emerger/config.ps1"
        run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_ps); up_ps '' -y -v -nc -nt --dev --only npm --json 2>'$HOME/err'"
        [ "$status" -eq 0 ]
        [ "${#lines[@]}" -eq 1 ]
        [[ "${lines[0]}" == '{"ts":'*'"managers":[{"name":"npm","result":"ok","secs":'[0-9]*'}]}' ]]
        grep -q 'hook out' "$HOME/err"
        grep -q 'hook host' "$HOME/err"
        grep -q 'npm out' "$HOME/err"
    done
    run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_ps); up_ps '' -y -v -nc -nt --dev --only npm 2>/dev/null"
    [[ "$output" == *"hook out"* ]]
    [[ "$output" == *"npm out"* ]]
}

@test "ps: an interrupted run stops before the next step and exits 1" {
    mkdir -p "$HOME/bin" "$HOME/hklm"
    printf '#!/bin/sh\necho "scoop $*" >>"%s/trace"\nif [ "$#" -eq 1 ]; then touch "%s/started"; exec sleep 30; fi\n' "$HOME" "$HOME" >"$HOME/bin/scoop"
    chmod +x "$HOME/bin/scoop"
    # Background jobs start with SIGINT ignored: restore it, as a terminal's Ctrl-C finds it.
    env --default-signal=INT PATH="$HOME/bin:$PATH" pwsh -NoProfile -NonInteractive -File "$REPO_DIR/src/emerger.ps1" -y -nc -nt -nl >"$HOME/out" 2>&1 &
    local pid=$! n=0
    while [ ! -e "$HOME/started" ] && [ "$n" -lt 150 ]; do sleep 0.1; n=$((n + 1)); done
    [ -e "$HOME/started" ]
    kill -INT "$pid"
    local rc=0
    wait "$pid" || rc=$?
    cat "$HOME/out"
    [ "$rc" -eq 1 ]
    [ "$(cat "$HOME/trace")" = "scoop update" ]
    grep -q 'Interrupted (SIGINT), stopping.' "$HOME/out"
    grep -q '|WARN|interrupted' "$LOCALAPPDATA/emerger/state/emerger.log"
}

@test "ps: a MANAGER_TIMEOUT past the int range in milliseconds lets a verbose step finish" {
    printf '#!/bin/sh\necho done\n' >"$HOME/quick"; chmod +x "$HOME/quick"
    local t
    for t in 3000000 999999999; do
        run ps "\$script:UI_VERBOSE = \$true; \$script:MANAGER_TIMEOUT = $t; \$ok = Run-Cmd 'quick' -Exe '$HOME/quick'; \"ok=\$ok\""
        [ "$status" -eq 0 ]
        [[ "$output" == *"ok=True"* ]] || { echo "MANAGER_TIMEOUT=$t: $output"; return 1; }
        [[ "$output" != *"Cannot convert"* ]]
    done
}

@test "ps: the PowerShell host for children and the task is the console host in PSHOME" {
    run ps 'Run-PowerShell-Path; $PSHOME'
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == "${lines[1]}/pwsh" || "${lines[0]}" == "${lines[1]}/pwsh.exe" ]]
}

@test "ps: manager output with OSC, reset and control bytes is sanitised in the live line and the failure tail" {
    run ps '
        $script:PKG_CURRENT = "npm"
        $e = [char]27; $b = [char]7
        $null = Run-Cmd "evil step" -Exe sh -ArgList @("-c", "printf ''${e}]52;c;ZXZpbA==${b}${e}]0;pwned${b}${e}cok${b}\010\n${e}[31mred${e}[0m\n''; exit 1")'
    [[ "$output" == *"ok"* ]]
    [[ "$output" == *"red"* ]]
    [[ "$output" != *$'\e]'* ]]
    [[ "$output" != *$'\ec'* ]]
    [[ "$output" != *$'\a'* ]]
    [[ "$output" != *"52;c;"* ]]
    [[ "$output" != *$'\b'* ]]
}

@test "ps: UI-Sanitize removes OSC, lone ESC sequences, C1 and C0 controls but keeps tab" {
    run ps '
        $e = [char]27
        $t = "a${e}]8;;http://x${e}\link${e}]0;t$([char]7)b${e}cc${e}(Bd$([char]0x9d)e$([char]0x01)f`tg"
        "[" + (UI-Sanitize $t) + "]"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"[alinkbcdef"$'\t'"g]"* ]]
}

@test "ps: output without a newline is cut to a bounded line before parsing" {
    run ps '
        $script:Seen = [System.Collections.Generic.List[int]]::new()
        function Progress-Feed { param([string]$Line) $script:Seen.Add($Line.Length); return "" }
        Progress-Reset "choco" 0
        $state = @{ Log = (New-Object System.Text.StringBuilder); Carry = ""; HasTimedOut = $false }
        $chunk = "5" * 8192
        $carryMax = 0
        for ($i = 0; $i -lt 1024; $i++) { _Run-Consume $state $chunk; $carryMax = [math]::Max($carryMax, $state.Carry.Length) }
        _Run-Consume $state ("." * 100000 + "`n")
        "carrymax=$carryMax"
        "lines=$($script:Seen.Count) longest=$(($script:Seen | Measure-Object -Maximum).Maximum)"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"carrymax=1024"* ]]
    [[ "$output" == *"lines=1 longest=1024"* ]]
}

@test "ps: progress patterns on a hostile line run linear in its length" {
    # 1024 characters is the bound _Run-Consume enforces. The patterns must
    # not backtrack on it: each attempt is capped by a regex match timeout of
    # 250 ms, which a quadratic or cubic scan of 1024 dots or digits exceeds.
    run ps '
        $line = "Progress: Downloading x" + ("." * 1000)
        $rx = [regex]::new($script:PROGRESS_RX_CHOCO, "None", [TimeSpan]::FromMilliseconds(250))
        $r1 = $rx.IsMatch($line + " ")
        $rb = [regex]::new($script:PROGRESS_RX_BYTES, "None", [TimeSpan]::FromMilliseconds(250))
        $r2 = $rb.IsMatch("1" * 1000 + " ")
        $rp = [regex]::new($script:PROGRESS_RX_PERCENT, "None", [TimeSpan]::FromMilliseconds(250))
        $r3 = $rp.IsMatch("1" * 1000 + ".")
        "choco=$r1 bytes=$r2 percent=$r3"
        Progress-Reset choco 0; [void](Progress-Feed "Progress: Downloading git.install 2.1.0... 45%")
        "name=$($script:PROGRESS_STATE.Name) pct=$($script:PROGRESS_STATE.Percent)"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"choco=False bytes=False percent=False"* ]]
    [[ "$output" == *"name=git pct=45"* ]]
}

@test "ps: a manager line forging a ts|ERROR| entry is one log line with no pipe in the message" {
    printf 'printf "boom\\n2026-01-01T00:00:00Z|ERROR|forged\\n"\nexit 1\n' >"$HOME/payload.sh"
    run ps '
        $script:EMERGER_LOG = Join-Path $env:HOME "up.log"
        $script:PKG_CURRENT = "npm"
        $script:RETRY_ATTEMPTS = 1
        $null = Run-Cmd "evil step" -Exe sh -ArgList @((Join-Path $env:HOME "payload.sh"))
        $log = @(Get-Content -LiteralPath $script:EMERGER_LOG)
        "errors=$(@($log | Where-Object { $_ -like "*|ERROR|*" }).Count) forged=$(@($log | Where-Object { $_ -like "2026-01-01*" }).Count)"'
    [[ "$output" == *"errors=2 forged=0"* ]]
}
