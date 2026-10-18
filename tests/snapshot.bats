#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    setup_minbin
}

teardown() {
    teardown_env
}

@test "--snapshot: snapper failing aborts with exit 1 and names snapper" {
    stub snapper 'case "$1" in list-configs) echo "root | /";; *) echo "snapper: quota error" >&2; exit 3;; esac'
    stub sudo 'if [ "$1" = snapper ]; then shift; exec snapper "$@"; fi; echo "sudo $*" >>"$HOME/sudo.log"; exit 1'
    plugin pa ''
    run $EMERGER -y -nl -nc -nt --snapshot --only pa
    [ "$status" -eq 1 ]
    [[ "$output" == *"snapper"*"exit 3"* ]]
    [[ "$output" == *"No snapshot taken"* ]]
    [[ "$output" != *"No snapshot tool available"* ]]
    [ ! -e "$HOME/ran" ]
}

@test "--snapshot: no snapshot tool aborts with exit 1 before any manager" {
    plugin pa ''
    run env PATH="$STUBS:/usr/bin:/bin" $EMERGER -y -nl -nc -nt --snapshot --only pa
    [ "$status" -eq 1 ]
    [[ "$output" == *"No snapshot tool available"* ]]
    [[ "$output" == *"No snapshot taken"* ]]
    [[ "$output" != *"continuing without"* ]]
    [ ! -e "$HOME/ran" ]
}

@test "rollback: snapper number column is used, not the type" {
    stub snapper 'case "$*" in
  list-configs) echo "root | /" ;;
  "-c root list") printf " # | Type   | Pre # | Date | User | Cleanup | Description            | Userdata\n---+--------+-------+------+------+---------+------------------------+---------\n0  | single |       |      | root |         | current                |\n7  | single |       | now  | root | number  | eMerger pre-update x   |\n12-| single |       | now  | root | number  | eMerger pre-update y   |\n" ;;
esac'
    run sys_lib 'DRY_RUN=1; snapshot_rollback'
    [ "$status" -eq 0 ]
    [[ "$output" == *"snapper -c root rollback 12"* ]]
}

@test "rollback: snapper box-drawing table yields the latest eMerger snapshot number" {
    stub snapper 'case "$*" in
  list-configs) echo "root │ /" ;;
  "-c root list") printf " # │ Type   │ Description\n 9 │ single │ eMerger pre-update z\n" ;;
esac'
    run sys_lib 'DRY_RUN=1; snapshot_rollback'
    [[ "$output" == *"snapper -c root rollback 9"* ]]
}

@test "snapshot: snapper and timeshift run without sudo as root, through sudo as a user" {
    stub snapper 'case "$1" in list-configs) echo "root | /" ;; *) echo "snapper $*" >>"$HOME/calls"; exit 1 ;; esac'
    stub timeshift 'echo "timeshift $*" >>"$HOME/calls"'
    run sys_lib 'sys_is_root() { return 0; }; snapshot_create'
    [ "$status" -eq 0 ]
    [[ "$output" == *"timeshift snapshot created"* ]]
    grep -q '^snapper -c root create ' "$HOME/calls"
    grep -q '^timeshift --create ' "$HOME/calls"
    stub sudo 'echo "sudo $*" >>"$HOME/calls"; exec "$@"'
    rm "$HOME/calls"
    run sys_lib 'sys_is_root() { return 1; }; snapshot_create'
    [ "$status" -eq 0 ]
    grep -q '^sudo snapper -c root create ' "$HOME/calls"
    grep -q '^sudo timeshift --create ' "$HOME/calls"
}

@test "rollback: snapper rollback and timeshift restore run without sudo as root" {
    stub snapper 'case "$*" in
  list-configs) echo "root | /" ;;
  "-c root list") printf " # | Type   | Description\n7  | single | eMerger pre-update x\n" ;;
  *) echo "snapper $*" >>"$HOME/calls" ;;
esac'
    run sys_lib 'DRY_RUN=0; sys_is_root() { return 0; }; snapshot_rollback'
    [ "$status" -eq 0 ]
    [[ "$output" == *"Rollback queued"* ]]
    [ "$(cat "$HOME/calls")" = "snapper -c root rollback 7" ]
    rm "$STUBS/snapper" "$HOME/calls"
    stub timeshift 'echo "timeshift $*" >>"$HOME/calls"'
    run sys_lib 'DRY_RUN=0; sys_is_root() { return 0; }; snapshot_rollback'
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/calls")" = "timeshift --restore" ]
}

@test "rollback: long snapper list-configs output does not hide the root config" {
    stub snapper 'case "$*" in
  list-configs) awk "BEGIN { print \"root | /\"; for (i = 0; i < 400000; i++) print \"other | /x\" }" ;;
  "-c root list") printf " # | Type   | Description\n5  | single | eMerger pre-update x\n" ;;
esac'
    run sys_lib 'DRY_RUN=1; snapshot_rollback'
    [ "$status" -eq 0 ]
    [[ "$output" == *"snapper -c root rollback 5"* ]]
}
