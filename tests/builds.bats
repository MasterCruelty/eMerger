#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    setup_minbin
}

teardown() {
    teardown_env
}

# Create Rust project $1 (under HOME) with a cargo target directory of $2 KiB
# whose last build was $3 ("" for now).
project() {
    local dir="$HOME/$1"
    mkdir -p "$dir/target/debug"
    touch "$dir/Cargo.toml" "$dir/target/CACHEDIR.TAG"
    head -c $(( $2 * 1024 )) /dev/zero >"$dir/target/debug/blob"
    touch "$dir/target/.rustc_info.json"
    [ -z "${3:-}" ] || touch -d "$3" "$dir/target/.rustc_info.json"
}

@test "clean_builds: no Rust project prints nothing" {
    mkdir -p "$HOME/code/target"
    run sys_lib 'clean_builds; echo "rc=$?"'
    [ "$status" -eq 0 ]
    [ "$output" = "rc=0" ]
}

@test "clean_builds: lists cargo targets biggest first and removes the rows picked" {
    project code/big 3072 '10 days ago'
    project code/small 2048 ''
    project code/tiny 4
    project .hidden/p 4096
    project code/node_modules/p 4096
    mkdir -p "$HOME/code/notcargo/target"; touch "$HOME/code/notcargo/Cargo.toml"
    head -c 2097152 /dev/zero >"$HOME/code/notcargo/target/x"
    project code/big/target/nested 4096
    run sys_lib 'ui_ask() { echo "ASK $1"; UI_ANSWER=1; return 0; }; clean_builds'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Build artifacts"* ]]
    [[ "$output" == *" 1  ~/code/big  "*"built 10 days ago"*" 2  ~/code/small"*"built 0 days ago"* ]]
    [[ "$output" != *"tiny"* ]]
    [[ "$output" != *"hidden"* ]]
    [[ "$output" != *"node_modules"* ]]
    [[ "$output" != *"notcargo"* ]]
    [[ "$output" != *"nested"* ]]
    [[ "$output" == *"ASK Clean which?"* ]]
    [ ! -e "$HOME/code/big/target" ]
    [ -e "$HOME/code/big/Cargo.toml" ]
    [ -d "$HOME/code/small/target" ]
}

@test "clean_builds: kept under -y, skipped on no, DEEP_CLEAN_SKIP=cargo hides the section" {
    project code/big 2048
    run sys_lib 'ARG_YES=1; clean_builds; ARG_YES=0
                 ui_ask() { UI_ANSWER=n; return 0; }; clean_builds
                 echo @@; DEEP_CLEAN_SKIP=cargo; clean_builds'
    [ "$status" -eq 0 ]
    [[ "$output" == *"1 Rust build directories kept under -y: the next build would start from scratch"* ]]
    [[ "$output" == *"skipped"* ]]
    [ "${output#*@@}" = "" ]
    [ -d "$HOME/code/big/target" ]
}

@test "clean_builds: BUILD_SCAN_ROOTS lists several roots, a project outside HOME keeps its path, dry-run removes nothing" {
    project a/p 2048
    project b/q 2048
    local out="$BATS_TEST_TMPDIR/out"
    mkdir -p "$out/r/target"; touch "$out/r/Cargo.toml" "$out/r/target/CACHEDIR.TAG"
    head -c 2097152 /dev/zero >"$out/r/target/x"
    run sys_lib "BUILD_SCAN_ROOTS='$HOME/a::$HOME/missing:$out'; DRY_RUN=1; ui_ask() { UI_ANSWER=a; return 0; }; clean_builds"
    [ "$status" -eq 0 ]
    [[ "$output" == *"~/a/p"* ]]
    [[ "$output" != *"~/b/q"* ]]
    [[ "$output" == *"[dry-run] rm -rf -- $out/r/target"* ]]
    [[ "$output" == *"[dry-run] rm -rf -- $HOME/a/p/target"* ]]
    [ -d "$HOME/a/p/target" ]
}

@test "clean_builds: a target without .rustc_info.json is dated from the directory" {
    project code/p 2048
    rm "$HOME/code/p/target/.rustc_info.json"
    touch -d '5 days ago' "$HOME/code/p/target"
    run sys_lib 'ui_ask() { UI_ANSWER=n; return 0; }; clean_builds'
    [ "$status" -eq 0 ]
    [[ "$output" == *"built 5 days ago"* ]]
}
