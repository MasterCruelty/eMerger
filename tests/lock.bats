#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
}

teardown() {
    teardown_env
}

# Start a background lock holder for state directory $1 and wait until it
# holds the lock.
hold_lock() {
    "$BASH" -c "EMERGER_STATE='$1'; source '$LIB/load.sh' ui lock
             lock_acquire || exit 1; echo \$\$ >'$HOME/holder.pid'; touch '$HOME/held'; sleep 30" &
    local i
    for (( i=0; i<50; i++ )); do [[ -e $HOME/held ]] && return 0; sleep 0.1; done
    return 1
}

# Print 1 if fd 9 is open in the process running this, else 0.
FD9_PROBE='if [ -e /proc/self/fd/9 ]; then echo 1; else echo 0; fi'

@test "lock: -rc while another run holds the lock is refused, cache kept" {
    mkdir -p "$EMERGER_STATE" "$XDG_CACHE_HOME/emerger"
    echo apt >"$XDG_CACHE_HOME/emerger/detected"
    flock "$EMERGER_STATE/emerger.lock" sleep 30 &
    local holder=$!
    sleep 0.5
    run $EMERGER -rc
    kill "$holder"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Another eMerger run"* ]]
    [ -f "$XDG_CACHE_HOME/emerger/detected" ]
}

@test "lock: --rollback while another run holds the lock is refused" {
    mkdir -p "$EMERGER_STATE"
    flock "$EMERGER_STATE/emerger.lock" sleep 30 &
    local holder=$!
    sleep 0.5
    run $EMERGER --rollback
    kill "$holder"
    [ "$status" -eq 1 ]
    [[ "$output" == *"Another eMerger run"* ]]
}

@test "lock without flock: a fresh lock with no pid yet is not taken over" {
    mkdir -p "$HOME/bin"
    local c
    for c in mkdir rm cat sleep stat date touch; do ln -s "$(command -v "$c")" "$HOME/bin/$c"; done
    mkdir "$HOME/emerger.lock.d"
    run env PATH="$HOME/bin" "$BASH" -c "EMERGER_STATE='$HOME'; source '$LIB/load.sh' ui lock; lock_acquire; echo rc=\$?"
    [[ "$output" == *"rc=1"* ]]
    [ -d "$HOME/emerger.lock.d" ]
    touch -d '1 minute ago' "$HOME/emerger.lock.d"
    run env PATH="$HOME/bin" "$BASH" -c "EMERGER_STATE='$HOME'; source '$LIB/load.sh' ui lock; lock_acquire; echo rc=\$?"
    [[ "$output" == *"rc=0"* ]]
}

@test "lock without flock: a takeover racing another takeover never leaves two holders" {
    mkdir -p "$HOME/bin"
    local c
    for c in mkdir rm cat sleep stat date touch; do ln -s "$(command -v "$c")" "$HOME/bin/$c"; done
    mkdir "$HOME/emerger.lock.d"; echo 999999999 >"$HOME/emerger.lock.d/pid"
    sleep 30 & local live=$!
    # The first liveness probe stands in for a second run that takes the
    # stale lock over between this run's check and its removal.
    run env PATH="$HOME/bin" LIVE="$live" "$BASH" -c "EMERGER_STATE='$HOME'; source '$LIB/load.sh' ui lock
        kill() {
            if [[ \$1 == -0 && ! -e '$HOME/raced' ]]; then
                touch '$HOME/raced'; rm -rf '$HOME/emerger.lock.d'; mkdir '$HOME/emerger.lock.d'; echo \$LIVE >'$HOME/emerger.lock.d/pid'; return 1
            fi
            builtin kill \"\$@\"
        }
        lock_acquire; echo rc=\$?"
    local held; held=$(cat "$HOME/emerger.lock.d/pid")
    kill "$live"
    [[ "$output" == *"rc=1"* ]]
    [ "$held" = "$live" ]
    [ ! -e "$HOME/emerger.lock.d.break" ]
}

@test "lock without flock: a stale break lock refuses once, then the next run takes over" {
    mkdir -p "$HOME/bin"
    local c
    for c in mkdir rm cat sleep stat date touch; do ln -s "$(command -v "$c")" "$HOME/bin/$c"; done
    mkdir "$HOME/emerger.lock.d" "$HOME/emerger.lock.d.break"; echo 999999999 >"$HOME/emerger.lock.d/pid"
    run env PATH="$HOME/bin" "$BASH" -c "EMERGER_STATE='$HOME'; source '$LIB/load.sh' ui lock; lock_acquire; echo rc=\$?"
    [[ "$output" == *"rc=1"* ]]
    [ -d "$HOME/emerger.lock.d.break" ]
    touch -d '1 minute ago' "$HOME/emerger.lock.d.break"
    run env PATH="$HOME/bin" "$BASH" -c "EMERGER_STATE='$HOME'; source '$LIB/load.sh' ui lock; lock_acquire; echo rc=\$?"
    [[ "$output" == *"rc=1"* ]]
    [ ! -e "$HOME/emerger.lock.d.break" ]
    run env PATH="$HOME/bin" "$BASH" -c "EMERGER_STATE='$HOME'; source '$LIB/load.sh' ui lock; lock_acquire; echo rc=\$?"
    [[ "$output" == *"rc=0"* ]]
}

@test "lock without flock: attack two concurrent runs, expected second refused" {
    mkdir -p "$HOME/bin"
    local c
    for c in mkdir rm cat sleep touch; do ln -s "$(command -v "$c")" "$HOME/bin/$c"; done
    PATH="$HOME/bin" hold_lock "$HOME"
    run env PATH="$HOME/bin" "$BASH" -c "EMERGER_STATE='$HOME'; source '$LIB/load.sh' ui lock; lock_acquire; echo rc=\$?"
    [[ "$output" == *"rc=1"* ]]
    [[ "$output" == *"in progress"* ]]
}

@test "lock without flock: a dead holder's lock is taken over" {
    mkdir -p "$HOME/bin"
    local c
    for c in mkdir rm cat sleep; do ln -s "$(command -v "$c")" "$HOME/bin/$c"; done
    mkdir "$HOME/emerger.lock.d"; echo 999999999 >"$HOME/emerger.lock.d/pid"
    run env PATH="$HOME/bin" "$BASH" -c "EMERGER_STATE='$HOME'; source '$LIB/load.sh' ui lock; lock_acquire; echo rc=\$?; lock_release; [ -e '$HOME/emerger.lock.d' ] && echo left || echo gone"
    [ "${lines[0]}" = "rc=0" ]
    [ "${lines[1]}" = "gone" ]
}

@test "lock on an unopenable path: attack lock skipped, expected error" {
    run lib "EMERGER_STATE=$HOME/missing/dir; lock_acquire; echo rc=\$?"
    [[ "$output" == *"rc=1"* ]]
    [[ "$output" == *"$HOME/missing/dir/emerger.lock"* ]]
}

@test "lock refused: attack holder PID wiped, expected PID kept and named" {
    command -v flock >/dev/null || skip "flock not available"
    hold_lock "$HOME"
    local pid; pid=$(cat "$HOME/holder.pid")
    run lib "EMERGER_STATE=$HOME; lock_acquire; echo rc=\$?"
    [[ "$output" == *"rc=1"* ]]
    [[ "$output" == *"PID $pid"* ]]
    [[ "$output" != *"remove the lock file"* ]]
    [ "$(cat "$HOME/emerger.lock")" = "$pid" ]
}

@test "lock path: attack cron run without XDG_RUNTIME_DIR, expected same lock file" {
    mkdir -p "$HOME/st"
    run bash -c "EMERGER_STATE=$HOME/st; XDG_RUNTIME_DIR=$HOME/run; source '$LIB/load.sh' ui lock; lock_acquire; echo \$EMERGER_LOCK"
    [ "$output" = "$HOME/st/emerger.lock" ]
    [ -f "$HOME/st/emerger.lock" ]
}

@test "lock fd: attack children inheriting fd 9, expected closed in run_cmd, hooks and plugins" {
    [ -e /proc/self/fd ] || skip "no /proc"
    mkdir -p "$XDG_CONFIG_HOME/emerger/hooks/post.d" "$XDG_CONFIG_HOME/emerger/managers.d"
    printf '%s\n' "$FD9_PROBE >\"\$HOME/hook\"" >"$XDG_CONFIG_HOME/emerger/hooks/post.d/p.sh"
    cat >"$XDG_CONFIG_HOME/emerger/managers.d/q.sh" <<EOF
PM_PLUGIN_SLUG=q
pm_q_detect() { return 0; }
pm_q_run() { bash -c '$FD9_PROBE' >"\$HOME/plugin"; }
EOF
    run lib "exec 9>>$HOME/l; DRY_RUN=0
             run_cmd x sh -c '$FD9_PROBE >\$HOME/quiet'
             UI_VERBOSE=1 run_cmd x sh -c '$FD9_PROBE >\$HOME/verbose'
             hooks_run post; PKG_MANAGERS=(); plugins_load; plugin_run q
             $FD9_PROBE"
    [ "${lines[-1]}" = "1" ]
    [ "$(cat "$HOME/quiet")" = "0" ]
    [ "$(cat "$HOME/verbose")" = "0" ]
    [ "$(cat "$HOME/hook")" = "0" ]
    [ "$(cat "$HOME/plugin")" = "0" ]
}

@test "lock fd: attack hook leaves a background child, expected next run starts" {
    command -v flock >/dev/null || skip "flock not available"
    mkdir -p "$XDG_CONFIG_HOME/emerger/hooks/post.d"
    printf 'sleep 20 >/dev/null 2>&1 &\necho $! >"$HOME/bg.pid"\n' >"$XDG_CONFIG_HOME/emerger/hooks/post.d/bg.sh"
    run env PATH="$STUBS:$PATH" $EMERGER -y -nl -nc -nt --only none
    [ "$status" -eq 0 ]
    [ -f "$HOME/bg.pid" ]
    run env PATH="$STUBS:$PATH" $EMERGER -n -y -nl -nc -nt --only none
    [ "$status" -eq 0 ]
    [[ "$output" != *"in progress"* ]]
}

@test "stderr still works after taking the lock" {
    run bash -c "$EMERGER -n -y -nl -nc -nt --only none 2>&1 >/dev/null"
    [ "$status" -eq 0 ]
    [[ "$output" == *"No supported package managers detected"* ]]
}

@test "lock fd: attack the monitor and the sudo keep-alive, expected fd 9 closed in both" {
    [ -e /proc/self/fd ] || skip "no /proc"
    stub sudo 'exit 0'
    run lib "exec 9>>$HOME/l; UI_IS_TTY=1
             ui_monitor_start lbl /dev/null >/dev/null; mon=\$_MONITOR_PID
             run_sudo_keepalive 30; ka=\$SUDO_KEEPALIVE_PID
             echo \$ka >$HOME/ka.pid; sleep 0.3
             echo \"monitor=\$([ -e /proc/\$mon/fd/9 ] && echo 1 || echo 0) keepalive=\$([ -e /proc/\$ka/fd/9 ] && echo 1 || echo 0)\"
             ui_monitor_stop >/dev/null; kill \$ka"
    [[ "$output" == *"monitor=0 keepalive=0"* ]]
}

@test "lock fd: attack plugin detect and plugin run under --json, expected fd 9 closed" {
    [ -e /proc/self/fd ] || skip "no /proc"
    mkdir -p "$XDG_CONFIG_HOME/emerger/managers.d"
    cat >"$XDG_CONFIG_HOME/emerger/managers.d/q.sh" <<EOF
PM_PLUGIN_SLUG=q
pm_q_detect() { bash -c '$FD9_PROBE' >"\$HOME/detect"; return 0; }
pm_q_run() { bash -c '$FD9_PROBE' >"\$HOME/run-json" 2>&1; }
EOF
    run lib "exec 9>>$HOME/l; DRY_RUN=0; PKG_MANAGERS=(); plugins_load
             plugin_detect q; ARG_JSON=1 plugin_run q"
    [ "$(cat "$HOME/detect")" = "0" ]
    [ "$(cat "$HOME/run-json")" = "0" ]
}

@test "lock fd: attack tools run by diff, self-update, root helper, EEPROM check and notification, expected fd 9 closed" {
    [ -e /proc/self/fd ] || skip "no /proc"
    stub git 'echo "$([ "$1" = -C ] && echo "$3" || echo "$1") $([ -e /proc/self/fd/9 ] && echo 1 || echo 0)" >>"$HOME/git.fd"; exit 0'
    for t in brew rpi-eeprom-update notify-send; do
        stub "$t" "if [ -e /proc/self/fd/9 ]; then echo 1; else echo 0; fi >\"\$HOME/$t.fd\"; exit 0"
    done
    mkdir -p "$HOME/co/.git"
    run lib "exec 9>>$HOME/l; DRY_RUN=0; ARG_FIRMWARE=0; SUMMARY_ERRORS=0; SUMMARY_MANAGERS=(a); DISPLAY=:0
             diff_snapshot $HOME/snap
             self_update $HOME/co
             sys_as_root sh -c '$FD9_PROBE >$HOME/root.fd'
             rpi_eeprom_run ''
             source \"\$LIB/load.sh\" notify; notify_send_result"
    [ "$(cat "$HOME/brew.fd")" = "0" ]
    grep -q '^fetch 0$' "$HOME/git.fd"
    grep -q '^pull 0$' "$HOME/git.fd"
    ! grep -q '^\(fetch\|pull\) 1$' "$HOME/git.fd"
    [ "$(cat "$HOME/root.fd")" = "0" ]
    [ "$(cat "$HOME/rpi-eeprom-update.fd")" = "0" ]
    [ "$(cat "$HOME/notify-send.fd")" = "0" ]
}

@test "lock fd: attack osascript on macOS, expected fd 9 closed" {
    [ -e /proc/self/fd ] || skip "no /proc"
    stub osascript "if [ -e /proc/self/fd/9 ]; then echo 1; else echo 0; fi >\"\$HOME/osa.fd\"; exit 0"
    run lib "exec 9>>$HOME/l; SUMMARY_ERRORS=0; SUMMARY_MANAGERS=(a); unset DISPLAY WAYLAND_DISPLAY
             source \"\$LIB/load.sh\" notify; sys_is_macos() { return 0; }; notify_send_result"
    [ "$(cat "$HOME/osa.fd")" = "0" ]
}

@test "lock fd: attack the parallel manager subshell, expected fd 9 closed" {
    [ -e /proc/self/fd ] || skip "no /proc"
    command -v flock >/dev/null || skip "flock not available"
    plugin pp '' 'pm_pp_parallel() { return 0; }
pm_pp_icon() {
    if [ "$(readlink /proc/self/fd/2)" = "$EMERGER_STATE/parallel-pp.log" ]; then '"$FD9_PROBE"' >"$HOME/par.fd"; fi
    printf x
}'
    run $EMERGER -y -nl -nc -nt --parallel --only pp
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/par.fd")" = "0" ]
}
