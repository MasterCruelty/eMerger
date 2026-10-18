#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    setup_minbin
}

teardown() {
    teardown_env
}

@test "changelog: long apt changelog is shown, not reported missing" {
    stub apt '[ "$1" = changelog ] || exit 1; i=0; while [ $i -lt 5000 ]; do echo "line $i"; i=$((i+1)); done'
    run sys_lib 'changelog_show foo; echo rc=$?'
    [ "$status" -eq 0 ]
    [[ "$output" == *"line 0"* ]]
    [[ "$output" == *"line 59"* ]]
    [[ "$output" != *"line 60"* ]]
    [[ "$output" == *"rc=0" ]]
}

@test "changelog: dnf falls back to updateinfo, nothing found exits 1" {
    stub dnf 'case "$1" in changelog) exit 1 ;; updateinfo) echo "Update ID: FEDORA-1" ;; esac'
    run sys_lib 'changelog_show foo; echo rc=$?'
    [[ "$output" == *"Update ID: FEDORA-1"* ]]
    [[ "$output" == *"rc=0" ]]
    rm "$STUBS/dnf"
    run sys_lib 'changelog_show foo'
    [ "$status" -eq 1 ]
    [[ "$output" == *"No supported package manager with changelog info found."* ]]
}

@test "changelog: pacman output is labelled package info" {
    stub pacman '[ "$1" = "-Qi" ] && echo "Name            : foo"'
    run sys_lib 'changelog_show foo'
    [ "$status" -eq 0 ]
    [[ "$output" == *"package info (pacman has no changelog)"* ]]
    [[ "$output" == *"Name            : foo"* ]]
}

@test "changelog: attack escapes in apt, dnf, pacman and brew text, expected stripped" {
    esc='printf "pkg\n  * x \033]52;c;ZXZpbA==\007 \033[31mred\n"'
    stub apt "$esc"
    run sys_lib 'changelog_show pkg'
    [[ "$output" == *"red"* ]]
    [[ "$output" != *$'\033'"]52"* && "$output" != *$'\033'"[31m"* ]]
    rm "$STUBS/apt"
    stub dnf "$esc"
    run sys_lib 'changelog_show pkg'
    [[ "$output" == *"red"* && "$output" != *$'\033'"]52"* ]]
    rm "$STUBS/dnf"
    stub pacman "$esc"
    run sys_lib 'changelog_show pkg'
    [[ "$output" == *"red"* && "$output" != *$'\033'"]52"* ]]
    rm "$STUBS/pacman"
    stub brew "$esc"
    run sys_lib 'changelog_show pkg'
    [[ "$output" == *"red"* && "$output" != *$'\033'"]52"* ]]
}
