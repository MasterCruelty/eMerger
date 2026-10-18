#!/usr/bin/env bats
# PowerShell flag parser, short-circuits and the Unix-only flags, run through pwsh where it is installed.

load ps_helper

@test "ps: --accept-licenses is parsed and sets AcceptLicenses" {
    run ps '(Args-Parse @("--accept-licenses")).AcceptLicenses'
    [ "$status" -eq 0 ]
    [ "$output" = "True" ]
}

@test "ps: short flags -V -v -w -err reach the parser instead of common parameters" {
    run up_fn -V
    [ "$status" -eq 0 ]
    [ "$output" = "eMerger $(cat "$REPO_DIR/VERSION")" ]
    run up_fn -err
    [ "$status" -eq 0 ]
    [[ "$output" != *"ambiguous"* ]]
    run up_fn -n -v -w -nc -nt -nl
    [ "$status" -eq 0 ]
    [[ "$output" != *"ambiguous"* ]]
}

@test "ps: a value flag with a missing or empty value exits 2 with Missing value" {
    local f form
    for f in only except metrics profile changelog; do
        for form in "@('--$f')" "@('--$f', '')" "@('--$f=')" "@('--$f', '', '-n')"; do
            run ps "Args-Parse $form | Out-Null; 'parsed'"
            [ "$status" -eq 2 ] || { echo "--$f $form: status $status"; return 1; }
            [[ "$output" == *"Missing value for --$f"* ]]
            [[ "$output" != *parsed* ]]
        done
    done
    run ps "(Args-Parse @('--only', 'winget')).Only"
    [ "$status" -eq 0 ]
    [ "$output" = winget ]
}

@test "ps: a repeated --profile loads only the last one" {
    mkdir -p "$APPDATA/emerger/profiles.d"
    for p in first last; do printf 'Add-Content "%s/trace" "%s"\n' "$HOME" "$p" >"$APPDATA/emerger/profiles.d/$p.ps1"; done
    run up_ps '' --profile first --profile last -V
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/trace")" = last ]
    rm "$HOME/trace"
    run up_ps '' --profile=last --profile=first -V
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/trace")" = first ]
}

@test "ps: short-circuits run in the Unix order and -rc touches nothing" {
    mkdir -p "$HOME/bin" "$LOCALAPPDATA/emerger/state" "$LOCALAPPDATA/emerger/cache"
    printf '#!/bin/sh\necho "git $*" >>"%s/trace"\n' "$HOME" >"$HOME/bin/git"; chmod +x "$HOME/bin/git"
    run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_ps); up_ps '' --list-profiles -up"
    [ "$status" -eq 0 ]
    [[ "$output" == *"Available profiles"* ]]
    [ ! -e "$HOME/trace" ]
    echo '{"ts":"2026-01-01T00:00:00Z","duration":5,"errors":0,"reboot":0,"managers":[]}' >"$LOCALAPPDATA/emerger/state/history.jsonl"
    touch "$LOCALAPPDATA/emerger/cache/keep"
    run up_ps '' -rc --metrics "$HOME/m.prom"
    [ "$status" -eq 0 ]
    [[ "$output" == *"metrics written"* ]]
    [[ "$output" != *"detection cache"* ]]
    [ -e "$LOCALAPPDATA/emerger/cache/keep" ]
    [ -e "$HOME/m.prom" ]
    run up_ps '' -n -rc -nc -nt
    [ "$status" -eq 0 ]
    [ -e "$LOCALAPPDATA/emerger/cache/keep" ]
    [[ "$output" == *"Windows keeps no detection cache, nothing to clear"* ]]
}

@test "ps: --changed and --changelog warn and exit 0 without starting an upgrade" {
    mkdir -p "$HOME/bin"
    printf '#!/bin/sh\necho "scoop $*" >>"%s/trace"\n' "$HOME" >"$HOME/bin/scoop"; chmod +x "$HOME/bin/scoop"
    run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_ps); up_ps '' -y -nc -nt --changed"
    [ "$status" -eq 0 ]
    [[ "$output" == *"--changed is not supported on Windows"* ]]
    run env PATH="$HOME/bin:$PATH" bash -c "$(declare -f up_ps); up_ps '' -y -nc -nt --changelog git"
    [ "$status" -eq 0 ]
    [[ "$output" == *"--changelog is not supported on Windows"* ]]
    [ ! -e "$HOME/trace" ]
    [ ! -e "$LOCALAPPDATA/emerger/state/history.jsonl" ]
}

@test "ps: each Unix-only run flag warns and the run goes on" {
    local f
    for f in --firmware --no-firmware --snapshot --parallel --resume --download-only --deep-clean --refresh-mirrors; do
        run up_ps '' -n -y -nc -nt "$f"
        [ "$status" -eq 0 ] || { echo "$f: status $status"; return 1; }
        [[ "$output" == *"$f is not supported on Windows, ignored."* ]]
        [[ "$output" == *"eMerger summary"* ]]
    done
}

@test "ps: --rollback warns and exits 0 without starting an upgrade" {
    run up_ps '' -y -nc -nt --rollback
    [ "$status" -eq 0 ]
    [[ "$output" == *"--rollback is not supported on Windows, nothing to revert."* ]]
    [[ "$output" != *"eMerger summary"* ]]
    [ ! -e "$LOCALAPPDATA/emerger/state/history.jsonl" ]
}

@test "ps: -- ends the options as on Unix, the words after it are ignored" {
    run ps "(Args-Parse @('-n', '--', '-y', '--bogus')).Yes; 'p=[' + (Args-Prescan-Profile @('--', '--profile', 'work')) + ']'"
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = False ]
    [ "${lines[1]}" = 'p=[]' ]
    run up_ps '' -n -nc -nt -- --bogus
    [ "$status" -eq 0 ]
    [[ "$output" != *"Unknown argument"* ]]
}

@test "ps: an unknown argument names up --help in double quotes" {
    run up_ps '' --bogus
    [ "$status" -eq 2 ]
    [ "$output" = 'Unknown argument: --bogus (try "up --help")' ]
}

@test "ps: -rc says Windows keeps no detection cache and removes nothing" {
    mkdir -p "$LOCALAPPDATA/emerger/cache"
    touch "$LOCALAPPDATA/emerger/cache/keep"
    run up_ps '' -rc -nc -nt -y
    [ "$status" -eq 0 ]
    [[ "$output" == *"Windows keeps no detection cache, nothing to clear"* ]]
    [[ "$output" != *"Detection cache cleared"* ]]
    [ -e "$LOCALAPPDATA/emerger/cache/keep" ]
}

@test "ps: --list-profiles lists the profiles in name order even when the directory lists them unsorted" {
    mkdir -p "$APPDATA/emerger/profiles.d"
    local name
    for name in alpha beta gamma; do printf '# description: %s\n' "$name" >"$APPDATA/emerger/profiles.d/$name.ps1"; done
    run up_ps 'function Get-ChildItem { $all = @(Microsoft.PowerShell.Management\Get-ChildItem @args); [array]::Reverse($all); $all }' --list-profiles
    [ "$status" -eq 0 ]
    local order
    order=$(printf '%s\n' "$output" | grep -oE '^  (alpha|beta|gamma|home|safe|server|work) ' | tr -d ' ' | tr '\n' ' ')
    [ "$order" = "alpha beta gamma home safe server work " ]
}

@test "ps: --profile is consumed by the prescan and leaves no Profile field in the options" {
    run ps '$o = Args-Parse @("--profile", "work", "-n"); "dry=$($o.DryRun) field=$($o.PSObject.Properties.Name -contains "Profile")"'
    [ "$status" -eq 0 ]
    [ "$output" = "dry=True field=False" ]
    run ps 'Args-Parse @("--profile") | Out-Null'
    [ "$status" -eq 2 ]
    [[ "$output" == *"Missing value for --profile"* ]]
}
