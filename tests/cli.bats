#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    # Managers the tests rely on, so detection does not depend on the host.
    for m in apt snap; do printf '#!/bin/sh\nexit 0\n' >"$STUBS/$m"; chmod +x "$STUBS/$m"; done
    printf '#!/bin/sh\necho "sudo $*" >>"$HOME/sudo.log"\n' >"$STUBS/sudo"; chmod +x "$STUBS/sudo"
}

teardown() {
    teardown_env
}

# Assert that value flag $1 refuses an empty value in both spellings.
empty_value_refused() {
    run $EMERGER -n -y "--$1" ""
    [ "$status" -eq 2 ]
    [[ "$output" == *"Missing value for --$1"* ]]
    run $EMERGER -n -y "--$1="
    [ "$status" -eq 2 ]
    [[ "$output" == *"Missing value for --$1"* ]]
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

@test "cli: --help -nl exits 0, -nl not read as a -n bundle" {
    run $EMERGER --help -nl
    [ "$status" -eq 0 ]
}

@test "cli: --errors on an empty log exits 0" {
    run $EMERGER --errors
    [ "$status" -eq 0 ]
}

@test "cli: bundled short flags -nv run as -n -v and exit 0" {
    run $EMERGER -nv -y -nl -ni -nc -nt -q
    [ "$status" -eq 0 ]
}

@test "unknown long flag still fails with exit code 2" {
    run $EMERGER --no-such-flag
    [ "$status" -eq 2 ]
}

@test "args: --flag=VALUE sets each value flag, the value kept whole after its first =" {
    run bash -c "source '$REPO_DIR/src/lib/load.sh' args
        args_parse --only=a=b --changelog=c --metrics=m --profile=p --except=e
        echo \"\$ARG_ONLY|\$ARG_CHANGELOG|\$ARG_METRICS|\$ARG_EXCEPT\""
    [ "$status" -eq 0 ]
    [ "$output" = "a=b|c|m|e" ]
    run $EMERGER --json=1
    [ "$status" -eq 2 ]
    [[ "$output" == *"Unknown argument: --json=1"* ]]
}

@test "--only and --except trim spaces around names" {
    plugin pa ''
    plugin pb ''
    plugin pc ''
    run $EMERGER -y -nl -nc -nt --only "pa, pb"
    [ "$status" -eq 0 ]
    [ "$(sort "$HOME/ran" | tr '\n' ' ')" = "pa pb " ]
    rm "$HOME/ran"
    run $EMERGER -y -nl -nc -nt --only "pa,pb,pc" --except "pa, pb"
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/ran")" = "pc" ]
}

@test "args: --only with an empty value exits 2" { empty_value_refused only; }

@test "args: --except with an empty value exits 2" { empty_value_refused except; }

@test "args: --changelog with an empty value exits 2" { empty_value_refused changelog; }

@test "args: --metrics with an empty value exits 2" { empty_value_refused metrics; }

@test "args: --profile with an empty value exits 2" { empty_value_refused profile; }

@test "--except appends to the profile list" {
    run bash -c "source '$LIB/load.sh' args; ARG_EXCEPT=yay,paru; args_parse --except snap --except=npm; echo \$ARG_EXCEPT"
    [ "$output" = "yay,paru,snap,npm" ]
}

@test "cli: --accept-licenses sets ARG_ACCEPT_LICENSES to 1" {
    run bash -c "source '$LIB/load.sh' args; args_parse --accept-licenses; echo \$ARG_ACCEPT_LICENSES"
    [ "$output" = "1" ]
}

@test "args: --profile is read by the prescan only, no ARG_PROFILE is left behind" {
    run bash -c "source '$REPO_DIR/src/lib/load.sh' args
        args_parse --profile p; args_prescan_profile --profile p
        echo \"[\${ARG_PROFILE-unset}] \$PROFILE_PRELOAD\""
    [ "$status" -eq 0 ]
    [ "$output" = "[unset] p" ]
}

@test "args: a newline inside a value never becomes an extra flag" {
    run $EMERGER --changelog $'pkg\n--version' -nl -ni
    [[ "$output" != *"eMerger $(cat "$REPO_DIR/VERSION")"* ]]
    [[ "$output" != "$(cat "$REPO_DIR/VERSION")" ]]
    run lib 'args_parse --only $'"'"'none\n--history'"'"'; echo "[${ARG_HISTORY}] [${ARG_ONLY}]"'
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == "[0] [none" ]]
}
