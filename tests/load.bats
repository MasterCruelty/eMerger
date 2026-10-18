#!/usr/bin/env bats

load test_helper

setup() {
    setup_home
}

teardown() {
    teardown_home
}

@test "load.sh: all defines a function of every module" {
    run bash -c 'source "$LIB/load.sh" all; declare -F ui_ok sys_has pkg_detect lock_acquire trust_home metrics_export | wc -l'
    [ "$status" -eq 0 ]
    [ "$output" -eq 6 ]
}

@test "load.sh: a file stem loads that module only" {
    run bash -c 'source "$LIB/load.sh" sys; declare -F sys_has >/dev/null && echo sys; declare -F ui_ok >/dev/null || echo no-ui'
    [ "$status" -eq 0 ]
    [ "$output" = $'sys\nno-ui' ]
}

@test "load.sh: an unknown name prints it, loads nothing and returns 1" {
    run bash -c 'source "$LIB/load.sh" sys nosuch; echo "rc=$?"; declare -F sys_has || echo none'
    [ "$status" -eq 0 ]
    [ "$output" = $'load.sh: unknown module nosuch\nrc=1\nnone' ]
}

@test "load.sh: leaves the caller's positional parameters and no helper variable" {
    run bash -c 'source "$LIB/load.sh" sys; echo "$# $1"; declare -p _load_dir _load_names _load_name 2>&1 | grep -c "not found"' _ one two
    [ "$status" -eq 0 ]
    [ "$output" = $'2 one\n3' ]
}

@test "load.sh: a directory name loads every module in it, a module path that one" {
    run bash -c 'source "$LIB/load.sh" ui; declare -F ui_glyph _ui_strip ui_ok ui_monitor_start ui_confirm | wc -l
                 declare -F knob_int || echo no-knobs'
    [ "$status" -eq 0 ]
    [ "$output" = $'5\nno-knobs' ]
    run bash -c 'source "$LIB/load.sh" ui/term; declare -F ui_glyph >/dev/null && echo term; declare -F ui_ok || echo no-print'
    [ "$output" = $'term\nno-print' ]
}

@test "load.sh: lists every module file under src/lib exactly once" {
    run bash -c 'source "$LIB/load.sh"; printf "%s\n" "${_LOAD_MODULES[@]}" | sort'
    [ "$status" -eq 0 ]
    [ "$output" = "$(cd "$LIB" && find . -name '*.sh' ! -name load.sh | sed 's|^\./||; s|\.sh$||' | sort)" ]
}
