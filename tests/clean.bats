#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    setup_minbin
}

teardown() {
    teardown_env
}

@test "clean_cache: du partial failure continues cleaning" {
    mkdir -p "$HOME/.cache/junk"
    head -c 200000 /dev/zero >"$HOME/.cache/junk/blob"
    stub du 'for a; do case $a in -*) ;; *) printf "300\t%s\n" "$a" ;; esac; done; exit 1'
    run sys_lib 'ARG_YES=1; clean_cache; echo "rc=$?"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"cache cleaned"* ]]
    [[ "$output" == *"rc=0"* ]]
}

@test "clean_trash: du failure still empties the trash" {
    mkdir -p "$HOME/.local/share/Trash/files" "$HOME/.local/share/Trash/info"
    touch "$HOME/.local/share/Trash/files/old"
    stub du 'echo "4	$3"; exit 1'
    run sys_lib 'ARG_YES=1; clean_trash; echo "rc=$? freed=$SUMMARY_FREED_KB"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"trash emptied"* ]]
    [[ "$output" == *"rc=0 freed=0"* ]]
    [ ! -e "$HOME/.local/share/Trash/files/old" ]
}

@test "clean_trash: growing trash never makes freed negative" {
    mkdir -p "$HOME/.local/share/Trash/files"
    touch "$HOME/.local/share/Trash/files/old"
    stub du 'n=$(cat "$HOME/du.n" 2>/dev/null || echo 0); n=$((n + 1)); echo $n >"$HOME/du.n"; echo "$((n * 100))	x"'
    run sys_lib 'ARG_YES=1; SUMMARY_FREED_KB=5; clean_trash; echo "freed=$SUMMARY_FREED_KB"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"freed=5"* ]]
}

@test "clean_cache: CACHE_EXCLUDE glob is not expanded against the cwd" {
    mkdir -p "$HOME/.cache/keepme" "$HOME/.cache/junk" "$HOME/cwd"
    touch "$HOME/cwd/keepsake"
    head -c 200000 /dev/zero >"$HOME/.cache/junk/blob"
    head -c 200000 /dev/zero >"$HOME/.cache/keepme/blob"
    run sys_lib 'cd "$HOME/cwd"; ARG_YES=1; CACHE_EXCLUDE="keep*"; clean_cache'
    [ "$status" -eq 0 ]
    [ -d "$HOME/.cache/keepme" ]
    [ ! -e "$HOME/.cache/junk" ]
}

@test "cache menu pick: leading zeros read as decimal" {
    run sys_lib '_clean_parse_pick "010" 12; echo "${_CLEAN_PICK[@]}"
                 _clean_parse_pick "08 09-10" 12; echo "${_CLEAN_PICK[@]}"'
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "10" ]
    [ "${lines[1]}" = "8 9 10" ]
}

@test "cache menu pick: huge range is clamped, duplicates counted once" {
    run timeout 10 bash -c "$(declare -f sys_lib); sys_lib '_clean_parse_pick \"1-999999999 2 2 3-1\" 3; echo \"\${_CLEAN_PICK[@]}\"'"
    [ "$status" -eq 0 ]
    [ "$output" = "1 2 3" ]
}

@test "deep clean: zero-byte journal and failing probes skip the task, run continues" {
    stub journalctl 'echo "Archived and active journals take up 0B in the file system."'
    stub dnf 'exit 1'
    stub go 'exit 1'
    stub docker 'case "$1" in info) exit 0 ;; *) exit 1 ;; esac'
    run sys_lib 'DRY_RUN=1; ARG_YES=1; clean_deep; echo "rc=$?"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"rc=0"* ]]
    [[ "$output" != *"vacuum-size"* ]]
    [[ "$output" == *"image prune -f"*"_ docker"* ]]
}

@test "deep clean: journal size in plain bytes is compared" {
    stub journalctl 'echo "Archived and active journals take up 512B in the file system."'
    run sys_lib 'DRY_RUN=1; ARG_YES=1; JOURNAL_MAX_SIZE=100; clean_deep; echo "rc=$?"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"[dry-run] journalctl --vacuum-size=100"* ]]
}

@test "deep clean: dry-run never calls sudo for the docker probe" {
    stub docker 'exit 1'
    stub sudo 'echo "$*" >>"$HOME/sudo.calls"; exit 0'
    run sys_lib 'sys_is_root() { return 1; }; DRY_RUN=1; ARG_YES=1; clean_deep; echo "rc=$?"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"rc=0"* ]]
    [ ! -e "$HOME/sudo.calls" ]
}

@test "clean_trash: macOS empties ~/.Trash" {
    stub uname 'echo Darwin'
    mkdir -p "$HOME/.Trash"
    touch "$HOME/.Trash/old"
    run sys_lib 'ARG_YES=1; clean_trash'
    [ "$status" -eq 0 ]
    [[ "$output" == *"trash emptied"* ]]
    [ ! -e "$HOME/.Trash/old" ]
}

@test "clean_trash: macOS Trash unreadable without Full Disk Access is reported, not called empty" {
    stub uname 'echo Darwin'
    mkdir -p "$HOME/.Trash"
    touch "$HOME/.Trash/old"
    stub find 'echo "find: $1: Operation not permitted" >&2; exit 1'
    run sys_lib 'ARG_YES=1; clean_trash; echo "rc=$?"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"cannot read the Trash (macOS privacy settings)"* ]]
    [[ "$output" != *"empty"* ]]
    [[ "$output" == *"rc=0"* ]]
    [ -e "$HOME/.Trash/old" ]
}

@test "clean_trash: an unreadable Linux Trash is reported, not called empty" {
    mkdir -p "$HOME/.local/share/Trash/files"
    stub find 'exit 1'
    run sys_lib 'ARG_YES=1; clean_trash; echo "rc=$?"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"cannot read the Trash"* ]]
    [[ "$output" != *"privacy"* ]]
    [[ "$output" != *"empty"* ]]
}

@test "deep clean: DEEP_CLEAN_SKIP glob is not expanded against the cwd" {
    mkdir -p "$HOME/cwd" && touch "$HOME/cwd/journal"
    run sys_lib 'cd "$HOME/cwd"; DEEP_CLEAN_SKIP="jour*"; _deep_is_skipped journal && echo skip || echo run
                 DEEP_CLEAN_SKIP="docker, journal"; _deep_is_skipped journal && echo skip || echo run'
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = run ]
    [ "${lines[1]}" = skip ]
}

@test "cache menu pick: ranges, commas and "a" select rows in order, empty selects none" {
    run lib '_clean_parse_pick "1 3-4,9" 5; echo "${_CLEAN_PICK[@]}"
             _clean_parse_pick a 3; echo "${_CLEAN_PICK[@]}"
             _clean_parse_pick "" 3; echo "[${_CLEAN_PICK[*]}]"'
    [ "${lines[0]}" = "1 3 4" ]
    [ "${lines[1]}" = "1 2 3" ]
    [ "${lines[2]}" = "[]" ]
}

@test "clean_cache -y keeps emerger and CACHE_EXCLUDE" {
    mkdir -p "$HOME/.cache/emerger" "$HOME/.cache/keepme" "$HOME/.cache/junk"
    head -c 200000 /dev/zero >"$HOME/.cache/junk/blob"
    head -c 200000 /dev/zero >"$HOME/.cache/keepme/blob"
    run lib 'ARG_YES=1; DRY_RUN=0; SUMMARY_FREED_KB=0; CACHE_EXCLUDE="keep*"; clean_cache'
    [ "$status" -eq 0 ]
    [ -d "$HOME/.cache/emerger" ]
    [ -d "$HOME/.cache/keepme" ]
    [ ! -e "$HOME/.cache/junk" ]
}

@test "clean_cache: entry named with the unit separator never deletes a CACHE_EXCLUDE entry" {
    mkdir -p "$HOME/.cache/emerger" "$HOME/.cache/keepme" "$HOME/.cache/big"
    head -c 300000 /dev/zero >"$HOME/.cache/big/blob"
    head -c 200000 /dev/zero >"$HOME/.cache/keepme/blob"
    head -c 100000 /dev/zero >"$HOME/.cache/a"$'\x1f'keepme
    run lib 'ARG_YES=1; DRY_RUN=0; SUMMARY_FREED_KB=0; CACHE_MENU_ROWS=1; CACHE_EXCLUDE="keepme"; clean_cache'
    [ "$status" -eq 0 ]
    [ -d "$HOME/.cache/keepme" ]
    [ ! -e "$HOME/.cache/big" ]
    [ ! -e "$HOME/.cache/a"$'\x1f'keepme ]
}

@test "--deep-clean under dry-run exits 0 and prints the Deep clean section" {
    run $EMERGER -n -y -nl -nc -nt --deep-clean --only none
    [ "$status" -eq 0 ]
    [[ "$output" == *"Deep clean"* ]]
}
