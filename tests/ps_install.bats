#!/usr/bin/env bats
# PowerShell installer (install.ps1), run through pwsh where it is installed.

load ps_helper

@test "ps: install refuses to shadow an existing up command" {
    mkdir -p "$HOME/bin"; printf '#!/bin/sh\necho other\n' >"$HOME/bin/up"; chmod +x "$HOME/bin/up"
    run env PATH="$HOME/bin:$PATH" pwsh -NoProfile -NonInteractive -File "$REPO_DIR/install.ps1"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$HOME/bin/up"* ]]
    run pwsh -NoProfile -NonInteractive -Command 'Test-Path $PROFILE.CurrentUserAllHosts'
    [ "$output" = "False" ] || ! grep -q emerger "$(pwsh -NoProfile -Command '$PROFILE.CurrentUserAllHosts')"
}

@test "ps: install registers up when no other up exists" {
    run pwsh -NoProfile -NonInteractive -File "$REPO_DIR/install.ps1"
    [ "$status" -eq 0 ]
    grep -q 'emerger.ps1' "$(pwsh -NoProfile -Command '$PROFILE.CurrentUserAllHosts')"
}

@test "ps: install install path with quote and subexpression stays literal in the profile" {
    local dir="$HOME/a'b\$(ni pwned)"
    mkdir -p "$dir"
    cp -r "$REPO_DIR/install.ps1" "$REPO_DIR/VERSION" "$REPO_DIR/src" "$dir/"
    run pwsh -NoProfile -NonInteractive -File "$dir/install.ps1"
    [ "$status" -eq 0 ]
    run bash -c "cd '$HOME' && pwsh -NoProfile -NonInteractive -Command '. \$PROFILE.CurrentUserAllHosts; up --version'"
    [ ! -e "$HOME/pwned" ]
    [ "$status" -eq 0 ]
    [[ "$output" == *"eMerger "* ]]
}

@test "ps: install leaves a Restricted ExecutionPolicy alone without an answer" {
    run pwsh -NoProfile -NonInteractive -Command "
        function Get-ExecutionPolicy { param(\$Scope) 'Restricted' }
        function Set-ExecutionPolicy { New-Item -ItemType File '$HOME/policy-changed' | Out-Null }
        & '$REPO_DIR/install.ps1'
        exit \$LASTEXITCODE" </dev/null
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/policy-changed" ]
    [[ "$output" == *"Set-ExecutionPolicy -Scope CurrentUser RemoteSigned"* ]]
}

@test "ps: install install path with a typographic quote stays literal in the profile" {
    local dir="$HOME/a’; New-Item -ItemType File pwned; & ’x"
    mkdir -p "$dir"
    cp -r "$REPO_DIR/install.ps1" "$REPO_DIR/VERSION" "$REPO_DIR/src" "$dir/"
    run pwsh -NoProfile -NonInteractive -File "$dir/install.ps1"
    [ "$status" -eq 0 ]
    run bash -c "cd '$HOME' && pwsh -NoProfile -NonInteractive -Command '. \$PROFILE.CurrentUserAllHosts; up --version'"
    [ ! -e "$HOME/pwned" ]
    [ "$status" -eq 0 ]
    [[ "$output" == *"eMerger "* ]]
}

@test "ps: uninstall without a terminal keeps settings, history and cache and says how to remove them" {
    mkdir -p "$APPDATA/emerger" "$LOCALAPPDATA/emerger"; touch "$APPDATA/emerger/config.ps1"
    run pwsh -NoProfile -NonInteractive -File "$REPO_DIR/uninstall.ps1" </dev/null
    [ "$status" -eq 0 ]
    [ -e "$APPDATA/emerger/config.ps1" ]
    [[ "$output" == *"Remove manually"* ]]
}

@test "ps: uninstall answering y on a terminal deletes settings, history and cache" {
    mkdir -p "$APPDATA/emerger" "$LOCALAPPDATA/emerger"; touch "$APPDATA/emerger/config.ps1"
    run bash -c "{ sleep 4; printf 'y\r'; } | script -qec \"pwsh -NoProfile -File '$REPO_DIR/uninstall.ps1'\" /dev/null"
    [ "$status" -eq 0 ]
    [ ! -e "$APPDATA/emerger" ]
    [ ! -e "$LOCALAPPDATA/emerger" ]
}
