#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
}

teardown() {
    teardown_env
}

# Run trust_file on a dummy file with stat reporting "$1" and id reporting
# group $2 (gid) named $3 for a user named $4.
trust_with() {
    stub stat "echo '$1'"
    stub id "case \$1 in -g) echo $2 ;; -gn) echo $3 ;; -un) echo $4 ;; *) echo 0 ;; esac"
    touch "$HOME/f"
    lib "PATH=$STUBS:\$PATH; trust_file $HOME/f; echo rc=\$?"
}

@test "state files: attack other users read the log, expected 0700 dir and 0600 log" {
    run bash -c "umask 022; $EMERGER -n -y -nl -nc -nt --only none"
    [ "$status" -eq 0 ]
    [ "$(stat -c %a "$XDG_STATE_HOME/emerger")" = "700" ]
    [ "$(stat -c %a "$XDG_CACHE_HOME/emerger")" = "700" ]
    [ "$(stat -c %a "$XDG_STATE_HOME/emerger/emerger.log")" = "600" ]
}

@test "config trust: attack group-writable config.sh, expected refused" {
    printf 'touch "$HOME/M"\n' >"$XDG_CONFIG_HOME/emerger/config.sh"
    chmod 666 "$XDG_CONFIG_HOME/emerger/config.sh"
    run $EMERGER -n -y -nl -nc -nt --only none
    [ "$status" -eq 1 ]
    [[ "$output" == *"config.sh"*"writable"* ]]
    [ ! -e "$HOME/M" ]
}

@test "trust_file: accepts own files and private-group write, refuses other owners, group or other write and unreadable modes" {
    local me; me=$(id -u)
    run trust_with "$me 500 644" 500 alice alice
    [ "${lines[-1]}" = "rc=0" ]
    run trust_with "$me 500 664" 500 alice alice
    [ "${lines[-1]}" = "rc=0" ]
    run trust_with "$me 27 664" 500 alice alice
    [ "${lines[-1]}" = "rc=1" ]
    [[ "$output" == *"writable by group"* ]]
    run trust_with "$me 500 664" 500 staff alice
    [ "${lines[-1]}" = "rc=1" ]
    run trust_with "$me 500 646" 500 alice alice
    [ "${lines[-1]}" = "rc=1" ]
    run trust_with "4242 500 600" 500 alice alice
    [ "${lines[-1]}" = "rc=1" ]
    [[ "$output" == *"not owned by you"* ]]
    run trust_with "garbage" 500 alice alice
    [ "${lines[-1]}" = "rc=1" ]
}

@test "profile trust: attack profile owned by another user, expected refused" {
    [ "$(stat -L -c %u /etc/os-release)" != "$(id -u)" ] || skip "running as the owner of /etc/os-release"
    mkdir -p "$XDG_CONFIG_HOME/emerger/profiles.d"
    ln -s /etc/os-release "$XDG_CONFIG_HOME/emerger/profiles.d/evil.sh"
    run $EMERGER -n -y -nl -nc -nt --only none --profile evil
    [ "$status" -eq 2 ]
    [[ "$output" == *"evil.sh"*"not owned"* ]]
}

@test "plugin and hook trust: attack group-writable files, expected skipped" {
    mkdir -p "$XDG_CONFIG_HOME/emerger/hooks/post.d" "$XDG_CONFIG_HOME/emerger/managers.d"
    printf 'touch "$HOME/hook"\n' >"$XDG_CONFIG_HOME/emerger/hooks/post.d/h.sh"
    printf 'touch "$HOME/plugin"\nPM_PLUGIN_SLUG=z\n' >"$XDG_CONFIG_HOME/emerger/managers.d/z.sh"
    chmod 666 "$XDG_CONFIG_HOME/emerger/hooks/post.d/h.sh" "$XDG_CONFIG_HOME/emerger/managers.d/z.sh"
    run env PATH="$STUBS:$PATH" $EMERGER -y -nl -nc -nt --only none
    [ "$status" -eq 0 ]
    [[ "$output" == *"h.sh"*"writable"* ]]
    [[ "$output" == *"z.sh"*"writable"* ]]
    [ ! -e "$HOME/hook" ]
    [ ! -e "$HOME/plugin" ]
}

@test "hook trust: attack a hooks directory writable by others, expected skipped" {
    mkdir -p "$XDG_CONFIG_HOME/emerger/hooks/post.d"
    printf 'touch "$HOME/hook"\n' >"$XDG_CONFIG_HOME/emerger/hooks/post.d/h.sh"
    chmod 644 "$XDG_CONFIG_HOME/emerger/hooks/post.d/h.sh"
    chmod 757 "$XDG_CONFIG_HOME/emerger/hooks/post.d"
    run env PATH="$STUBS:$PATH" $EMERGER -y -nl -nc -nt --only none
    [ "$status" -eq 0 ]
    [[ "$output" == *"post.d"*"writable"* ]]
    [ ! -e "$HOME/hook" ]
}

@test "root trust: attack sudo -E with a user HOME, expected refused" {
    [ "$(id -u)" -eq 0 ] || skip "needs uid 0 (run under unshare -r)"
    [ "$(stat -c %u /)" != 0 ] || skip "no directory owned by another uid"
    run env HOME=/ $EMERGER -n -y -nl -nc -nt --only none
    [ "$status" -eq 1 ]
    [[ "$output" == *"HOME"* ]]
}

@test "checkout: attack a library file writable by other, expected refusal before any module loads" {
    mkdir -p "$HOME/co"
    cp -r "$REPO_DIR/src" "$REPO_DIR/VERSION" "$HOME/co/"
    chmod -R go-w "$HOME/co"
    run env PATH="$STUBS:$PATH" bash "$HOME/co/src/emerger.sh" -V
    [ "$status" -eq 0 ]
    chmod o+w "$HOME/co/src/lib/log.sh"
    run env PATH="$STUBS:$PATH" bash "$HOME/co/src/emerger.sh" -V
    [ "$status" -eq 1 ]
    [[ "$output" == *"log.sh is writable by group or other"* ]]
    chmod o-w "$HOME/co/src/lib/log.sh"
    chmod o+w "$HOME/co/src/lib"
    run env PATH="$STUBS:$PATH" bash "$HOME/co/src/emerger.sh" -V
    [ "$status" -eq 1 ]
}

@test "checkout: attack a group-writable file when the user has no private group, expected refusal" {
    mkdir -p "$HOME/co"
    cp -r "$REPO_DIR/src" "$REPO_DIR/VERSION" "$HOME/co/"
    chmod -R go-w "$HOME/co"
    chmod g+w "$HOME/co/src/lib/log.sh"
    # The group is the caller's own: accepted only while the group is private to the user.
    run env PATH="$STUBS:$PATH" bash "$HOME/co/src/emerger.sh" -V
    [ "$status" -eq 0 ]
    stub id 'case "$1" in -gn) echo shared;; -un) echo me;; *) exec /usr/bin/id "$@";; esac'
    run env PATH="$STUBS:$PATH" bash "$HOME/co/src/emerger.sh" -V
    [ "$status" -eq 1 ]
    [[ "$output" == *"log.sh is writable by group or other"* ]]
}
