#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    setup_minbin
    export FAKE_PROC="$HOME/proc"
    mkdir -p "$FAKE_PROC/self/fd"
}

teardown() {
    rm -f "/dev/shm/emerger-test-$$ (deleted)"
    teardown_env
}

# Give fake process $1 named $2 descriptor $3 open on file $4, which a real
# /proc shows with " (deleted)" appended once it is unlinked.
fake_fd() {
    mkdir -p "$FAKE_PROC/$1/fd"
    [[ -n $2 ]] && printf '%s\n' "$2" >"$FAKE_PROC/$1/comm"
    ln -s "$4" "$FAKE_PROC/$1/fd/$3"
}

# Create file $1 of $2 MiB of real blocks.
blob() {
    head -c $(( $2 * 1048576 )) /dev/zero >"$1"
}

@test "clean_open_deleted: per command, biggest first, a file shared by two descriptors counted once" {
    blob "$HOME/a (deleted)" 2
    blob "$HOME/b (deleted)" 3
    touch "$HOME/live"
    fake_fd 100 code 3 "$HOME/a (deleted)"
    fake_fd 100 code 4 "$HOME/a (deleted)"
    fake_fd 200 tracker-miner-f 3 "$HOME/b (deleted)"
    fake_fd 200 tracker-miner-f 4 "$HOME/live"
    run sys_lib '_CLEAN_PROC="$FAKE_PROC"; clean_open_deleted; echo "rc=$?"'
    [ "$status" -eq 0 ]
    [[ "${lines[0]}" == *"5M held by deleted files still open, freed when their holders close"* ]]
    [[ "${lines[1]}" == *"tracker-miner-f"*"3M"* ]]
    [[ "${lines[2]}" == *"code"*"2M"* ]]
    [ "${lines[3]}" = "rc=0" ]
}

@test "clean_open_deleted: under 1M in all prints nothing" {
    head -c 500000 /dev/zero >"$HOME/a (deleted)"
    fake_fd 100 code 3 "$HOME/a (deleted)"
    run sys_lib '_CLEAN_PROC="$FAKE_PROC"; clean_open_deleted; echo "rc=$?"'
    [ "$status" -eq 0 ]
    [ "$output" = "rc=0" ]
}

@test "clean_open_deleted: unreadable comm names the pid, a vanished target is skipped" {
    blob "$HOME/a (deleted)" 2
    fake_fd 300 "" 3 "$HOME/a (deleted)"
    fake_fd 400 ghost 3 "$HOME/gone (deleted)"
    run sys_lib '_CLEAN_PROC="$FAKE_PROC"; clean_open_deleted'
    [ "$status" -eq 0 ]
    [[ "$output" == *"pid 300"*"2M"* ]]
    [[ "$output" != *"ghost"* ]]
}

@test "clean_open_deleted: only the biggest CLEAN_OPEN_ROWS holders are listed" {
    local n
    for n in 1 2 3 4 5 6; do
        blob "$HOME/f$n (deleted)" "$n"
        fake_fd "$n" "proc$n" 3 "$HOME/f$n (deleted)"
    done
    run sys_lib '_CLEAN_PROC="$FAKE_PROC"; clean_open_deleted'
    [ "$status" -eq 0 ]
    [[ "$output" == *"21M held"* ]]
    [[ "$output" == *"proc6"* ]]
    [[ "$output" == *"proc2"* ]]
    [[ "$output" != *"proc1 "* ]]
}

@test "clean_open_deleted: a file on another filesystem than / and HOME is left out" {
    [[ -d /dev/shm && -w /dev/shm ]] || skip "no writable /dev/shm"
    [[ $(stat -c %d /dev/shm) != "$(stat -c %d /)" && $(stat -c %d /dev/shm) != "$(stat -c %d "$HOME")" ]] \
        || skip "/dev/shm shares a filesystem with / or HOME"
    blob "/dev/shm/emerger-test-$$ (deleted)" 2
    fake_fd 100 shm 3 "/dev/shm/emerger-test-$$ (deleted)"
    run sys_lib '_CLEAN_PROC="$FAKE_PROC"; clean_open_deleted; echo "rc=$?"'
    [ "$status" -eq 0 ]
    [ "$output" = "rc=0" ]
}

@test "clean_open_deleted: an unreadable HOME does not stop the run" {
    blob "$HOME/a (deleted)" 2
    fake_fd 100 code 3 "$HOME/a (deleted)"
    run sys_lib '_CLEAN_PROC="$FAKE_PROC"; HOME="$HOME/missing"; clean_open_deleted; echo "rc=$?"'
    [ "$status" -eq 0 ]
    [[ "$output" == *"2M held"* ]]
    [[ "$output" == *"rc=0"* ]]
}

@test "clean_open_deleted: without /proc (macOS) prints nothing" {
    run sys_lib '_CLEAN_PROC="$HOME/missing"; clean_open_deleted; echo "rc=$?"'
    [ "$status" -eq 0 ]
    [ "$output" = "rc=0" ]
}

@test "clean_open_deleted: the real /proc shows a deleted file this shell holds" {
    [[ -d /proc/self/fd ]] || skip "no /proc"
    run sys_lib 'exec 3>"$HOME/held"; head -c 3000000 /dev/zero >&3; rm "$HOME/held"; clean_open_deleted'
    [ "$status" -eq 0 ]
    [[ "$output" == *"held by deleted files still open"* ]]
    [[ "$output" == *"bash"* ]]
}
