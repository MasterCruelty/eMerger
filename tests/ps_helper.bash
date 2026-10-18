# Shared fixture of the PowerShell tests: temp HOME, and runners for a
# pwsh snippet, the entry point and the profile function.

setup() {
    command -v pwsh >/dev/null || skip "pwsh not installed"
    export REPO_DIR="${BATS_TEST_DIRNAME}/.."
    export PSLIB="$REPO_DIR/src/pslib"
    export HOME_BAK="$HOME"
    export HOME="$(mktemp -d)"
    export APPDATA="$HOME/AppData/Roaming" LOCALAPPDATA="$HOME/AppData/Local"
    export NO_COLOR=1
    mkdir -p "$APPDATA" "$LOCALAPPDATA"
}

teardown() {
    [ -n "${HOME_BAK:-}" ] || return 0
    rm -rf "$HOME"
    export HOME="$HOME_BAK"
}

# File name the caller gives the elevated child for its result.
RESULT_LEAF=emerger-0123456789abcdef0123456789abcdef.json

# Run pwsh snippet $1 with the libraries dot-sourced and default arguments.
ps() {
    pwsh -NoProfile -NonInteractive -Command "
        \$ErrorActionPreference = 'Stop'
        \$script:EMERGER_STATE = Join-Path \$env:LOCALAPPDATA 'emerger/state'
        \$script:EMERGER_CONFIG = Join-Path \$env:APPDATA 'emerger'
        foreach (\$f in 'ui/Term','ui/Text','ui/Print','ui/Monitor','ui/Prompt','managers/Progress','Log',
                       'Sys','state/Lock','system/Preflight','Elevated','Args','Run','managers/Packages',
                       'state/Estimate') { . (Join-Path '$PSLIB' \"\$f.ps1\") }
        \$script:ArgsGlobal = Args-Parse @()
        UI-Init
        $1"
}

# Run src/emerger.ps1 with $1 as a prelude (stubs defined before the entry
# point), the rest as its arguments. HKLM: maps to $HOME/hklm.
up_ps() {
    local prelude="$1"; shift
    local args="" word
    for word in "$@"; do args+=" '${word//\'/\'\'}'"; done
    mkdir -p "$HOME/hklm"
    pwsh -NoProfile -NonInteractive -Command "
        New-PSDrive -Name HKLM -PSProvider FileSystem -Root '$HOME/hklm' -Scope Global | Out-Null
        $prelude
        & '$REPO_DIR/src/emerger.ps1' $args
        exit \$LASTEXITCODE"
}

# Write the elevation tests' stubs: a choco on PATH, a config.ps1 and a post
# hook that each append to $HOME/trace whether they ran in the elevated
# child, and a Start-Process that runs the "elevated" process with
# EMERGER_TEST_ELEVATED=1 instead of asking UAC.
elevation_stubs() {
    mkdir -p "$HOME/bin" "$APPDATA/emerger/hooks/post.d"
    printf '#!/bin/sh\necho "choco elevated=${EMERGER_TEST_ELEVATED:-0}" >>"%s/trace"\necho "Chocolatey upgraded 1/3 packages."\nexit ${CHOCO_RC:-0}\n' "$HOME" >"$HOME/bin/choco"
    chmod +x "$HOME/bin/choco"
    # The elevated child finds choco only in the system locations.
    export ProgramData="$HOME/ProgramData"
    mkdir -p "$ProgramData/chocolatey"
    ln -sfn "$HOME/bin" "$ProgramData/chocolatey/bin"
    printf 'Add-Content "%s/trace" "config elevated=$([int]$env:EMERGER_TEST_ELEVATED)"\n' "$HOME" >"$APPDATA/emerger/config.ps1"
    printf 'Add-Content "%s/trace" "hook elevated=$([int]$env:EMERGER_TEST_ELEVATED)"\n' "$HOME" >"$APPDATA/emerger/hooks/post.d/t.ps1"
    START_PROCESS_STUB="function Start-Process {
        param(\$FilePath, \$ArgumentList, \$Verb, [switch]\$Wait, [switch]\$PassThru)
        Add-Content '$HOME/trace' \"start verb=\$Verb\"
        if (\$env:DECLINE_UAC) { throw 'The operation was canceled by the user.' }
        \$exe = if (\$FilePath -match '^powershell') { (Get-Process -Id \$PID).Path } else { \$FilePath }
        \$startInfo = [Diagnostics.ProcessStartInfo]::new(\$exe, (@(\$ArgumentList) -join ' '))
        \$startInfo.UseShellExecute = \$false
        \$startInfo.Environment['EMERGER_TEST_ELEVATED'] = '1'
        \$startInfo.RedirectStandardOutput = \$true
        \$process = [Diagnostics.Process]::Start(\$startInfo)
        Set-Content '$HOME/child.out' \$process.StandardOutput.ReadToEnd()
        \$process.WaitForExit()
        [pscustomobject]@{ ExitCode = \$process.ExitCode }
    }"
}

# Call `up` the way the profile function from install.ps1 does (splatted
# @args), so single-dash flags reach the script as PowerShell would pass them.
up_fn() {
    local args="" word
    for word in "$@"; do args+=" $word"; done
    pwsh -NoProfile -NonInteractive -Command "
        function up { & '$REPO_DIR/src/emerger.ps1' @args }
        up $args
        exit \$LASTEXITCODE"
}

# Hold lock file $1 (default run.lock) in the state directory from another
# pwsh until $HOME/held appears, the holder's PID written to $HOME/holder.
hold_lock() {
    local lock_file="$LOCALAPPDATA/emerger/state/${1:-run.lock}"
    mkdir -p "$LOCALAPPDATA/emerger/state"
    pwsh -NoProfile -NonInteractive -Command "
        \$lock = [IO.File]::Open('$lock_file', 'OpenOrCreate', 'ReadWrite', 'None')
        New-Item -ItemType File '$HOME/held' | Out-Null
        Start-Sleep 30" >/dev/null 2>&1 &
    echo $! >"$HOME/holder"
    local tries=0
    while [ ! -e "$HOME/held" ] && [ "$tries" -lt 100 ]; do sleep 0.1; tries=$((tries + 1)); done
}
