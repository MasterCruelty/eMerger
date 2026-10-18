#!/usr/bin/env bats

load test_helper

setup() {
    setup_home
}

teardown() {
    teardown_home
}

# Stub systemctl: the user bus answers, `enable` exits with $1.
stub_systemctl() {
    cat >"$STUBS/systemctl" <<EOS
#!/bin/bash
echo "systemctl \$*" >>"\$HOME/systemctl.log"
[[ \$* == *enable* ]] && { echo "Failed to connect to bus: No medium found" >&2; exit $1; }
exit 0
EOS
    chmod +x "$STUBS/systemctl"
}

# Run autoupdate_install with the stubs first on PATH.
run_setup_cron() {
    bash -c 'PATH="$STUBS:$PATH"; source "$LIB/load.sh" ui log sys autoupdate
             DRY_RUN=0; autoupdate_install "$1"' _ "$REPO_DIR"
}

@test "auto-update: the systemd timer fires on Sunday at 10:00 like cron and Windows" {
    stub_systemctl 0
    run run_setup_cron
    [ "$status" -eq 0 ]
    grep -qx 'OnCalendar=Sun \*-\*-\* 10:00:00' "$HOME/.config/systemd/user/emerger.timer"
}

@test "auto-update: a failing enable explains itself, removes the units and exits 1" {
    stub_systemctl 1
    run run_setup_cron
    [ "$status" -eq 1 ]
    [[ "$output" == *"loginctl enable-linger"* ]]
    [ ! -e "$HOME/.config/systemd/user/emerger.timer" ]
    [ ! -e "$HOME/.config/systemd/user/emerger.service" ]
}

@test "auto-update: attack % and \$ in the install path, expected refused" {
    stub crontab 'cat >>"$HOME/crontab-called"'
    run lib "PATH=$STUBS:\$PATH; DRY_RUN=0; sys_has() { [[ \$1 != systemctl ]] && command -v \"\$1\" >/dev/null; }
             autoupdate_install '$HOME/a%b'; echo rc=\$?; autoupdate_install '$HOME/a\$b'; echo rc=\$?"
    [[ "$output" == *"rc=1"*"rc=1"* ]]
    [ ! -e "$HOME/crontab-called" ]
}

@test "auto-update: cron line quotes a path with a space" {
    stub crontab '[ "$1" = "-l" ] && { echo "no crontab for u" >&2; exit 1; }; cat >>"$HOME/crontab-called"'
    run lib "PATH=$STUBS:\$PATH; DRY_RUN=0; sys_has() { [[ \$1 != systemctl ]] && command -v \"\$1\" >/dev/null; }
             autoupdate_install '$HOME/p q'; echo rc=\$?"
    [[ "$output" == *"rc=0"* ]]
    [ "$(cat "$HOME/crontab-called")" = "0 10 * * 0 bash \"$HOME/p q/src/emerger.sh\" -y -q -nl -ni" ]
}

@test "auto-update: attack unreadable crontab, expected refusal without rewriting it" {
    stub crontab '[ "$1" = "-l" ] && { echo "crontab: temporary read failure" >&2; exit 1; }; cat >>"$HOME/crontab-called"'
    run lib "PATH=$STUBS:\$PATH; DRY_RUN=0; sys_has() { [[ \$1 != systemctl ]] && command -v \"\$1\" >/dev/null; }
             autoupdate_install '$HOME/p'; echo rc=\$?"
    [[ "$output" == *"rc=1"* ]]
    [ ! -e "$HOME/crontab-called" ]
}

@test "auto-update: cron install keeps unrelated lines and replaces only its own" {
    printf '%s\n' '0 3 * * * /opt/backup/emerger.sh --sync' '0 10 * * 0 bash "/old/src/emerger.sh" -y -q -nl -ni' '5 5 * * * mine' >"$HOME/crontab-in"
    stub crontab 'if [ "$1" = "-l" ]; then cat "$HOME/crontab-in"; else cat >"$HOME/crontab-called"; fi'
    run lib "PATH=$STUBS:\$PATH; DRY_RUN=0; sys_has() { [[ \$1 != systemctl ]] && command -v \"\$1\" >/dev/null; }
             autoupdate_install '$HOME/p'; echo rc=\$?"
    [[ "$output" == *"rc=0"* ]]
    [ "$(cat "$HOME/crontab-called")" = "$(printf '%s\n' '0 3 * * * /opt/backup/emerger.sh --sync' '5 5 * * * mine' "0 10 * * 0 bash \"$HOME/p/src/emerger.sh\" -y -q -nl -ni")" ]
}

@test "install_path_check: attack each refused character alone, expected refusal; plain path accepted" {
    local c
    for c in "'" '"' '$' '`' '%' '\' $'\n'; do
        export BAD_CHAR="$c"
        run lib 'install_path_check "/opt/a${BAD_CHAR}b"'
        [ "$status" -eq 1 ]
    done
    run lib 'install_path_check "/opt/a b-c_d.e"'
    [ "$status" -eq 0 ]
}
