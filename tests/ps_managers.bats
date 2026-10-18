#!/usr/bin/env bats
# PowerShell manager recipes and selection, run through pwsh where it is installed.

load ps_helper

@test "ps: winget accepts agreements only with --accept-licenses" {
    run ps '$script:ArgsGlobal.DryRun = $true; Pkg-Run winget | Out-Null'
    [ "$status" -eq 0 ]
    [[ "$output" != *"accept-package-agreements"* ]]
    [[ "$output" == *"--accept-licenses"* ]]
    run ps '$script:ArgsGlobal.DryRun = $true; $script:ArgsGlobal.AcceptLicenses = $true; Pkg-Run winget | Out-Null'
    [ "$status" -eq 0 ]
    [[ "$output" == *"--accept-package-agreements --accept-source-agreements"* ]]
}

@test "ps: --security skips each manager with no security channel and warns" {
    mkdir -p "$HOME/bin"
    for m in winget choco; do printf '#!/bin/sh\necho "%s ran" >>"%s/trace"\n' "$m" "$HOME" >"$HOME/bin/$m"; chmod +x "$HOME/bin/$m"; done
    run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_ps); up_ps '' -n -y -nc -nt --security"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skip winget: no security-only updates, --security never runs a full upgrade"* ]]
    [[ "$output" == *"skip choco: no security-only updates"* ]]
    [[ "$output" != *"[dry-run] choco"* ]]
    run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_ps); up_ps '' -n -y -nc -nt --accept-licenses"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[dry-run] choco upgrade all"* ]]
    [[ "$output" != *"skip choco"* ]]
}

@test "ps: verbose pip upgrade goes on to the next package after a failing one" {
    mkdir -p "$HOME/bin"
    printf '#!/bin/sh\nif [ "$1" = list ]; then echo %s; exit 0; fi\necho "install $4" >>"%s/trace"\necho "notice: new pip" >&2\n[ "$4" = b ]\n' \
        "'[{\"name\":\"a\"},{\"name\":\"b\"}]'" "$HOME" >"$HOME/bin/pip"
    chmod +x "$HOME/bin/pip"
    run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f ps); ps \"\$1\"" _ "
        \$PSNativeCommandUseErrorActionPreference = \$true
        \$script:UI_VERBOSE = \$true
        \$ok = Pkg-Run pip
        \"ok=\$ok\""
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/trace")" = "install a"$'\n'"install b" ]
    [[ "$output" == *"ok=False"* ]]
    [[ "$output" != *NativeCommand* ]]
}

@test "ps: Windows Update writing a non-terminating error fails the step" {
    local mod="$HOME/.local/share/powershell/Modules/PSWindowsUpdate"
    mkdir -p "$mod"
    printf 'function Get-WindowsUpdate { "Accepted [1] Updates"; if ($env:WU_FAIL) { Write-Error "0x80240022 install failed" } }\n' >"$mod/PSWindowsUpdate.psm1"
    run env WU_FAIL=1 bash -c "$(declare -f ps); ps \"\$1\"" _ '$ok = Pkg-Run PSWindowsUpdate; "ok=$ok"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok=False"* ]]
    [[ "$output" == *"0x80240022"* ]]
    run ps '$ok = Pkg-Run PSWindowsUpdate; "ok=$ok"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok=True"* ]]
}

@test "ps: --only and --except match manager names case-sensitively" {
    mkdir -p "$HOME/bin"
    for m in winget scoop; do printf '#!/bin/sh\n' >"$HOME/bin/$m"; chmod +x "$HOME/bin/$m"; done
    run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_ps); up_ps '' -n -y -nc -nt --only WINGET,scoop"
    [ "$status" -eq 0 ]
    [[ "$output" != *"[dry-run] winget"* ]]
    [[ "$output" == *"[dry-run] scoop update"* ]]
    run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_ps); up_ps '' -n -y -nc -nt --except SCOOP"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[dry-run] scoop update"* ]]
}

@test "ps: Windows Update installs and accepts EULAs only with --accept-licenses" {
    local mod="$HOME/.local/share/powershell/Modules/PSWindowsUpdate"
    mkdir -p "$mod"
    printf 'function Get-WindowsUpdate { [CmdletBinding(SupportsShouldProcess = $true)] param([switch]$AcceptAll, [switch]$Install, [switch]$IgnoreReboot, $Category)\n  Add-Content (Join-Path $env:HOME "wu") "accept=$AcceptAll install=$Install" }\n' >"$mod/PSWindowsUpdate.psm1"
    run ps '$ok = Pkg-Run PSWindowsUpdate; "ok=$ok"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"ok=True"* ]]
    [[ "$output" == *"run with --accept-licenses"* ]]
    [ "$(cat "$HOME/wu")" = "accept=False install=False" ]
    rm "$HOME/wu"
    run ps '$script:ArgsGlobal.AcceptLicenses = $true; $ok = Pkg-Run PSWindowsUpdate; "ok=$ok"'
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/wu")" = "accept=True install=True" ]
}

@test "ps: a comma list after --only or --except through the profile function names each manager" {
    mkdir -p "$HOME/bin"
    for m in winget scoop; do printf '#!/bin/sh\n' >"$HOME/bin/$m"; chmod +x "$HOME/bin/$m"; done
    run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_fn); up_fn -n -y -nc -nt -nl --only winget,scoop"
    [ "$status" -eq 0 ]
    [[ "$output" == *"[dry-run] winget"* ]]
    [[ "$output" == *"[dry-run] scoop update"* ]]
    run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_fn); up_fn -n -y -nc -nt -nl --except winget,scoop"
    [ "$status" -eq 0 ]
    [[ "$output" == *"skip winget (--except)"* ]]
    [[ "$output" == *"skip scoop (--except)"* ]]
}

@test "ps: choco upgrades (and accepts package licences) only with --accept-licenses" {
    run ps '$script:ArgsGlobal.DryRun = $true; Pkg-Run choco | Out-Null'
    [ "$status" -eq 0 ]
    [[ "$output" != *"upgrade all"* ]]
    [[ "$output" == *"[dry-run] choco outdated"* ]]
    [[ "$output" == *"upgrades not installed: they may need licence agreement, run with --accept-licenses"* ]]
    run ps '$script:ArgsGlobal.DryRun = $true; $script:ArgsGlobal.AcceptLicenses = $true; Pkg-Run choco | Out-Null'
    [ "$status" -eq 0 ]
    [[ "$output" == *"[dry-run] choco upgrade all -y"* ]]
    [[ "$output" != *"outdated"* ]]
}
