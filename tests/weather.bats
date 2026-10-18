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

@test "weather: empty curl output prints no line and the run goes on" {
    printf '#!/bin/sh\nexit 0\n' >"$STUBS/curl"; chmod +x "$STUBS/curl"
    run $EMERGER -n -y -w --only none
    [ "$status" -eq 0 ]
    [[ "$output" == *"No supported package managers"* ]]
}

@test "weather: attack OSC 52 from wttr.in, expected control bytes stripped" {
    stub curl 'printf "Rome: \033]52;c;SGVsbG8=\007sunny\033]0;t\007 +20C\r\n"'
    run env PATH="$STUBS:$PATH" $EMERGER -n -y -w -ni -nc -nt --only none
    [ "$status" -eq 0 ]
    [[ "$output" == *"sunny"* ]]
    [[ "$output" != *$'\e'* ]]
    [[ "$output" != *$'\a'* ]]
}

@test "weather: attack a 100 KB body from wttr.in, expected cut to 512 bytes" {
    stub curl 'head -c 100000 /dev/zero | tr "\0" x'
    run env PATH="$STUBS:$PATH" $EMERGER -n -y -w -ni -nc -nt --only none
    [ "$status" -eq 0 ]
    longest=$(printf '%s\n' "$output" | awk '{ if (length($0) > m) m = length($0) } END { print m }')
    [ "$longest" -gt 400 ]
    [ "$longest" -lt 600 ]
}
