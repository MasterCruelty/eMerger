#!/usr/bin/env bats

load test_helper

setup() {
    setup_home
    export XDG_CONFIG_HOME="$HOME/.config"
    export SHELL=/bin/bash
    touch "$HOME/.bashrc"
}

teardown() {
    teardown_home
}

@test "install adds the up alias when no up command exists" {
    run env PATH="$STUBS:/usr/bin:/bin" bash "$REPO_DIR/install.sh"
    [ "$status" -eq 0 ]
    grep -q "^alias up=.*emerger.sh" "$HOME/.bashrc"
}

@test "install refuses to shadow an existing up command" {
    printf '#!/bin/sh\necho other\n' >"$STUBS/up"; chmod +x "$STUBS/up"
    run env PATH="$STUBS:/usr/bin:/bin" bash "$REPO_DIR/install.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"$STUBS/up"* ]]
    ! grep -q "emerger.sh" "$HOME/.bashrc"
}

@test "install refuses to shadow an up alias already in the rc file" {
    echo "alias up='cd ..'" >>"$HOME/.bashrc"
    run env PATH="$STUBS:/usr/bin:/bin" bash "$REPO_DIR/install.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *".bashrc"* ]]
    ! grep -q "emerger.sh" "$HOME/.bashrc"
}

# Run install.sh with $1 written to file $2 under HOME; print the exit status.
setup_with_definition() {
    mkdir -p "$(dirname "$HOME/$2")"
    printf '%s\n' "$1" >>"$HOME/$2"
    run env PATH="$STUBS:/usr/bin:/bin" bash "$REPO_DIR/install.sh"
}

@test "install refuses to shadow 'function up {' in the rc file" {
    setup_with_definition 'function up { cd ..; }' .bashrc
    [ "$status" -eq 1 ]
}

@test "install refuses to shadow an up alias in ~/.bash_aliases" {
    setup_with_definition "alias up='cd ..'" .bash_aliases
    [ "$status" -eq 1 ]
    [[ "$output" == *".bash_aliases"* ]]
}

@test "install refuses to shadow a fish function named up" {
    setup_with_definition 'function up; cd ..; end' .config/fish/functions/up.fish
    [ "$status" -eq 1 ]
}

@test "install refuses a user up() beside an old eMerger alias" {
    printf "alias up='bash \"/old/src/emerger.sh\"'\n" >>"$HOME/.bashrc"
    setup_with_definition 'up() { cd ..; }' .bashrc
    [ "$status" -eq 1 ]
}

@test "install run twice keeps one alias and succeeds" {
    run env PATH="$STUBS:/usr/bin:/bin" bash "$REPO_DIR/install.sh"
    [ "$status" -eq 0 ]
    run env PATH="$STUBS:/usr/bin:/bin" bash "$REPO_DIR/install.sh"
    [ "$status" -eq 0 ]
    [ "$(grep -c 'emerger.sh' "$HOME/.bashrc")" -eq 1 ]
}

@test "install: attack install path with \$(cmd), expected refused" {
    local d="$HOME/x\$(touch \$HOME/M)y"
    mkdir -p "$d/src/lib"
    cp "$REPO_DIR/install.sh" "$d/"; cp -R "$LIB"/. "$d/src/lib/"; cp "$REPO_DIR/src/emerger.sh" "$d/src/"
    touch "$HOME/.bashrc"
    run env PATH="$STUBS:/usr/bin:/bin" SHELL=/bin/bash bash "$d/install.sh"
    [ "$status" -eq 1 ]
    [[ "$output" == *"install path"* ]]
    ! grep -q emerger.sh "$HOME/.bashrc" || false
    bash -c "source '$HOME/.bashrc'" || true
    [ ! -e "$HOME/M" ]
}

@test "install: install path with a space gives a working alias" {
    local d="$HOME/my dir"
    mkdir -p "$d/src/lib"
    cp "$REPO_DIR/install.sh" "$d/"; cp -R "$LIB"/. "$d/src/lib/"; cp "$REPO_DIR/src/emerger.sh" "$d/src/"
    touch "$HOME/.bashrc"
    run env PATH="$STUBS:/usr/bin:/bin" SHELL=/bin/bash bash "$d/install.sh"
    [ "$status" -eq 0 ]
    run bash -c "shopt -s expand_aliases; source '$HOME/.bashrc'; alias up"
    [ "$output" = "alias up='bash \"$d/src/emerger.sh\"'" ]
}

@test "install and uninstall: attack arithmetic payload in QUIET_LEVEL and UI_VERBOSE, expected no code run" {
    for script in install.sh uninstall.sh; do
        run env PATH="$STUBS:/usr/bin:/bin" "QUIET_LEVEL=HOME[\$(touch $HOME/m-q)]" "UI_VERBOSE=HOME[\$(touch $HOME/m-v)]" bash "$REPO_DIR/$script"
        [ ! -e "$HOME/m-q" ]
        [ ! -e "$HOME/m-v" ]
    done
}

@test "install installs the man page so man up finds it" {
    run env PATH="$STUBS:/usr/bin:/bin" bash "$REPO_DIR/install.sh"
    [ "$status" -eq 0 ]
    cmp "$REPO_DIR/man/up.1" "$HOME/.local/share/man/man1/up.1"
    [ "$(stat -c %a "$HOME/.local/share/man/man1/up.1")" = 644 ]
}
