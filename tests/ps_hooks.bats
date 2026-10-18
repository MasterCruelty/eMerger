#!/usr/bin/env bats
# PowerShell user hooks, run through pwsh where it is installed.

load ps_helper

@test "ps: a hook ending with exit 1 is reported as failed" {
    mkdir -p "$APPDATA/emerger/hooks/pre.d"
    printf 'exit 1\n' >"$APPDATA/emerger/hooks/pre.d/bad.ps1"
    printf '"good ran"\n' >"$APPDATA/emerger/hooks/pre.d/good.ps1"
    run ps ". (Join-Path \$env:PSLIB 'Hooks.ps1'); Log-Init; Hooks-Run pre; 'after'"
    [ "$status" -eq 0 ]
    [[ "$output" == *"hook bad.ps1 failed (exit 1)"* ]]
    [[ "$output" != *"hook good.ps1 failed"* ]]
    [[ "$output" == *"good ran"*after* ]]
    grep -q '|WARN|hook pre/bad.ps1 failed' "$LOCALAPPDATA/emerger/state/emerger.log"
}

@test "ps: hooks run in name order even when the directory lists them unsorted" {
    mkdir -p "$APPDATA/emerger/hooks/pre.d"
    local name
    for name in 10-a 20-b 30-c; do
        printf 'Add-Content "%s/trace" "%s"\n' "$HOME" "$name" >"$APPDATA/emerger/hooks/pre.d/$name.ps1"
    done
    # A filesystem that does not sort (FAT, a network share) lists entries in
    # any order: the stub returns them reversed.
    run ps ". (Join-Path \$env:PSLIB 'Hooks.ps1'); Log-Init
        function Get-ChildItem { \$all = @(Microsoft.PowerShell.Management\Get-ChildItem @args); [array]::Reverse(\$all); \$all }
        Hooks-Run pre"
    [ "$status" -eq 0 ]
    [ "$(tr '\n' ' ' <"$HOME/trace")" = "10-a 20-b 30-c " ]
}
