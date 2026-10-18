#!/usr/bin/env bats
# PowerShell settings from config.ps1 and profiles, run through pwsh where it is installed.

load ps_helper

@test "ps: a numeric knob that is not a whole number warns and falls back to its default" {
    mkdir -p "$APPDATA/emerger"
    printf '%s\n' '$script:MANAGER_TIMEOUT = -1' '$script:RETRY_ATTEMPTS = "3x"' '$script:DISK_MIN_FREE_MB = "lots"' \
        '$script:BATTERY_MIN_PCT = "20%"' '$script:RETRY_DELAY = "007"' >"$APPDATA/emerger/config.ps1"
    run up_ps 'function Get-PSDrive { [pscustomobject]@{ Free = 10MB } }' -n -y -nc -nt
    [ "$status" -eq 0 ]
    [[ "$output" == *'MANAGER_TIMEOUT="-1" is not a whole number, using 0'* ]]
    [[ "$output" == *'RETRY_ATTEMPTS="3x" is not a whole number, using 2'* ]]
    [[ "$output" == *'DISK_MIN_FREE_MB="lots" is not a whole number, using 1024'* ]]
    [[ "$output" == *'BATTERY_MIN_PCT="20%" is not a whole number, using 20'* ]]
    [[ "$output" != *RETRY_DELAY* ]]
    [[ "$output" == *"Low disk space"*"10MB free, threshold 1024MB"* ]]
}

@test "ps: UI_VERBOSE and Ascii set in config.ps1 or a profile take effect like -v and --ascii" {
    mkdir -p "$HOME/bin" "$APPDATA/emerger"
    printf '#!/bin/sh\necho "scoop said hi"\n' >"$HOME/bin/scoop"; chmod +x "$HOME/bin/scoop"
    run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_ps); up_ps '' -y -nc -nt"
    [ "$status" -eq 0 ]
    [[ "$output" != *"scoop said hi"* ]]
    printf '$script:UI_VERBOSE = $true\n' >"$APPDATA/emerger/config.ps1"
    run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_ps); up_ps '' -y -nc -nt"
    [ "$status" -eq 0 ]
    [[ "$output" == *"scoop said hi"* ]]
    run ps '$script:UI_VERBOSE = $true; $script:ArgsGlobal.Ascii = $true; UI-Init
        "v=$script:UI_VERBOSE n=$script:UI_IS_ASCII u=$script:UI_HAS_UNICODE e=$script:UI_HAS_EMOJI"'
    [ "$status" -eq 0 ]
    [ "$output" = "v=True n=True u=False e=False" ]
}

@test "ps: action and query fields set in config.ps1 or a profile have no effect, only the command line sets them" {
    mkdir -p "$HOME/bin" "$APPDATA/emerger/profiles.d"
    printf '#!/bin/sh\necho "git $*" >>"%s/trace"\n' "$HOME" >"$HOME/bin/git"; chmod +x "$HOME/bin/git"
    printf '%s\n' '$script:ArgsGlobal.SelfUpdate = $true' '$script:ArgsGlobal.History = $true' \
        '$script:ArgsGlobal.Metrics = "m.prom"' '$script:ArgsGlobal.Rollback = $true' >"$APPDATA/emerger/config.ps1"
    printf '%s\n' '$script:ArgsGlobal.AutoUpdate = $true' '$script:ArgsGlobal.Doctor = $true' \
        '$script:ArgsGlobal.Help = $true' '$script:ArgsGlobal.Reboot = $true' >"$APPDATA/emerger/profiles.d/acts.ps1"
    run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_ps); up_ps '' -n -nc -nt -nl -ni --profile acts"
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/trace" ]
    [[ "$output" == *"eMerger summary"* ]]
    [[ "$output" != *"No history yet"* ]]
    [[ "$output" != *"--rollback"* ]]
    [[ "$output" != *"USAGE"* ]]
    [[ "$output" != *"Auto-update"* ]]
    run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_ps); up_ps '' --history"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No history yet"* ]]
    [ ! -e "$HOME/trace" ]
}
