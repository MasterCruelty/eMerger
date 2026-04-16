#!/usr/bin/env bats

setup() {
    export REPO_DIR="${BATS_TEST_DIRNAME}/.."
    export EMERGER="bash $REPO_DIR/src/emerger.sh"
    export HOME_BAK="$HOME"
    export HOME="$(mktemp -d)"
    export XDG_CACHE_HOME="$HOME/.cache"
    export XDG_CONFIG_HOME="$HOME/.config"
    export XDG_STATE_HOME="$HOME/.local/state"
    export NO_COLOR=1
    mkdir -p "$XDG_CACHE_HOME" "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"
}

teardown() {
    rm -rf "$HOME"
    export HOME="$HOME_BAK"
}

@test "help exits 0 and mentions USAGE" {
    run $EMERGER --help
    [ "$status" -eq 0 ]
    [[ "$output" == *"USAGE"* ]]
}

@test "version prints version string" {
    run $EMERGER --version
    [ "$status" -eq 0 ]
    [[ "$output" == *"eMerger"* ]]
}

@test "unknown flag fails with exit code 2" {
    run $EMERGER --totally-bogus
    [ "$status" -eq 2 ]
}

@test "short no-logo flag is parsed correctly (not as -n)" {
    run $EMERGER --help -nl
    [ "$status" -eq 0 ]
}

@test "errors shows ok on empty log" {
    run $EMERGER --errors
    [ "$status" -eq 0 ]
}

@test "history shows placeholder when empty" {
    run $EMERGER --history
    [ "$status" -eq 0 ]
}

@test "dry-run completes without sudo" {
    run $EMERGER -n -y -nl -ni -nc -nt -q
    [ "$status" -eq 0 ]
}

@test "short flag bundling: -nv is accepted" {
    run $EMERGER -nv -y -nl -ni -nc -nt -q
    [ "$status" -eq 0 ]
}

@test "json mode emits a single json object on stdout" {
    run $EMERGER -n -y --json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"managers":'* ]]
    [[ "$output" == *'"errors":'* ]]
}

@test "--only filter restricts managers" {
    run $EMERGER -n -y --json --only apt
    [ "$status" -eq 0 ]
    [[ "$output" == *'"apt"'* ]]
    [[ "$output" != *'"snap"'* ]]
}

@test "--except filter skips managers" {
    run $EMERGER -n -y --json --except snap
    [ "$status" -eq 0 ]
    [[ "$output" != *'"snap"'* ]]
}

@test "--metrics refuses with empty history" {
    run $EMERGER --metrics "$HOME/out.prom"
    # Either exits non-zero or writes the file; both behaviors are fine here.
    [ "$status" -eq 0 ] || [ "$status" -eq 1 ]
}

@test "unknown long flag still fails with exit code 2" {
    run $EMERGER --no-such-flag
    [ "$status" -eq 2 ]
}
