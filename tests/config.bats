#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
}

teardown() {
    teardown_env
}

@test "config: ARG_ASCII=1 in config.sh gives ASCII glyphs" {
    echo 'ARG_ASCII=1' >"$XDG_CONFIG_HOME/emerger/config.sh"
    run env LANG=C.UTF-8 $EMERGER -n -y -nl --only none
    [ "$status" -eq 0 ]
    [[ "$output" == *"! No supported package managers"* ]]
    [[ "$output" != *"▲"* ]]
}

@test "config: DRY_RUN=1 and UI_VERBOSE=1 in config.sh act as -n and -v" {
    plugin pa 'run_cmd step echo noisy-manager'
    run $EMERGER -y -nl -nc -nt --only pa
    [ "$status" -eq 0 ]
    [[ "$output" != *"noisy-manager"* ]]
    echo 'UI_VERBOSE=1' >"$XDG_CONFIG_HOME/emerger/config.sh"
    run $EMERGER -y -nl -nc -nt --only pa
    [ "$status" -eq 0 ]
    [[ "$output" == *"noisy-manager"* ]]
    echo 'DRY_RUN=1' >"$XDG_CONFIG_HOME/emerger/config.sh"
    run $EMERGER -y -nl -nc -nt --only pa
    [ "$status" -eq 0 ]
    [[ "$output" == *"[dry-run] echo noisy-manager"* ]]
    [ "$(wc -l <"$EMERGER_STATE/history.jsonl")" -eq 2 ]
    [ "$(wc -l <"$HOME/ran")" -eq 3 ]
}

@test "quiet: -q and QUIET_LEVEL=1 in config.sh hide the logo" {
    local mark; mark=$(sed -n 2p "$REPO_DIR/src/logo/logo.txt")
    [ -n "$mark" ]
    run $EMERGER -n -y --only none
    [ "$status" -eq 0 ]
    [[ "$output" == *"$mark"* ]]
    run $EMERGER -n -y -q --only none
    [ "$status" -eq 0 ]
    [[ "$output" != *"$mark"* ]]
    echo 'QUIET_LEVEL=1' >"$XDG_CONFIG_HOME/emerger/config.sh"
    run $EMERGER -n -y --only none
    [ "$status" -eq 0 ]
    [[ "$output" != *"$mark"* ]]
}

@test "config: action variables in config.sh are ignored, only the command line runs actions" {
    mkdir -p "$STUBS"; printf '#!/bin/sh\necho "git $*" >>"$HOME/git.log"\n' >"$STUBS/git"; chmod +x "$STUBS/git"
    for var in ARG_SELF_UPDATE ARG_ERRORS ARG_HISTORY ARG_REBUILD_CACHE ARG_DOCTOR ARG_LIST_PROFILES; do
        echo "$var=1" >"$XDG_CONFIG_HOME/emerger/config.sh"
        run env PATH="$STUBS:$PATH" $EMERGER -n -y -nl --only none --json
        [ "$status" -eq 0 ] || { echo "$var: status $status"; false; }
        [[ "${lines[-1]}" == \{*\"managers\":[]*\} ]] || { echo "$var: $output"; false; }
    done
    [ ! -e "$HOME/git.log" ]
}

@test "config: the long-named action flags still run from the command line" {
    run $EMERGER --errors
    [ "$status" -eq 0 ]
    run bash -c "source '$LIB/args.sh'; args_parse -up -au -err -rc; echo \$ARG_SELF_UPDATE\$ARG_AUTO_UPDATE\$ARG_ERRORS\$ARG_REBUILD_CACHE"
    [ "$output" = "1111" ]
}

@test "config: a config.sh whose last command fails (test && assignment) still runs the update" {
    plugin pa ''
    printf '%s\n' 'ARG_KEEP_CACHE=1' '[[ -f /nonexistent ]] && ARG_KEEP_TRASH=1' >"$XDG_CONFIG_HOME/emerger/config.sh"
    run $EMERGER -y -nl -nt --only pa
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/ran")" = "pa" ]
}

@test "config: a failing command in the middle of config.sh does not stop later lines" {
    plugin pa ''
    printf '%s\n' 'false' 'ARG_ONLY=pa' >"$XDG_CONFIG_HOME/emerger/config.sh"
    plugin pb ''
    run $EMERGER -y -nl -nc -nt
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/ran")" = "pa" ]
}
