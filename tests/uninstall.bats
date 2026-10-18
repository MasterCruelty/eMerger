#!/usr/bin/env bats

load test_helper

setup() {
    setup_home
    export XDG_CONFIG_HOME="$HOME/.config"
    export SHELL=/bin/bash
    # crontab backed by a file; systemctl records its calls.
    cat >"$STUBS/crontab" <<'EOS'
#!/bin/bash
if [[ $1 == -l ]]; then [[ -s $HOME/crontab ]] && cat "$HOME/crontab"; exit 0; fi
[[ $1 == - ]] && cat >"$HOME/crontab"
EOS
    cat >"$STUBS/systemctl" <<'EOS'
#!/bin/bash
echo "systemctl $*" >>"$HOME/systemctl.log"
[[ $* == *list-unit-files* ]] && ls "$HOME/.config/systemd/user" 2>/dev/null
exit 0
EOS
    chmod +x "$STUBS/crontab" "$STUBS/systemctl"
    export PATH="$STUBS:$PATH"
}

teardown() {
    teardown_home
}

@test "uninstall: removes the only crontab line and still removes the timer" {
    echo '0 10 * * 0 bash "/x/src/emerger.sh" -y -q -nl -ni' >"$HOME/crontab"
    mkdir -p "$HOME/.config/systemd/user"
    touch "$HOME/.config/systemd/user/emerger.service" "$HOME/.config/systemd/user/emerger.timer"
    touch "$HOME/.bashrc"
    run bash "$REPO_DIR/uninstall.sh"
    [ "$status" -eq 0 ]
    [ ! -s "$HOME/crontab" ]
    [ ! -e "$HOME/.config/systemd/user/emerger.timer" ]
}

@test "uninstall: removes exactly what install.sh wrote and keeps the user's lines" {
    printf 'export EDITOR=vim\n# eMerger notes I wrote myself\nalias ll="ls -l"\n' >"$HOME/.bashrc"
    run env PATH="$STUBS:/usr/bin:/bin" bash "$REPO_DIR/install.sh"
    [ "$status" -eq 0 ]
    grep -q emerger.sh "$HOME/.bashrc"
    [ -e "$HOME/.local/share/bash-completion/completions/up" ]
    run bash "$REPO_DIR/uninstall.sh"
    [ "$status" -eq 0 ]
    ! grep -q emerger.sh "$HOME/.bashrc" || false
    grep -qx '# eMerger notes I wrote myself' "$HOME/.bashrc"
    grep -qx 'export EDITOR=vim' "$HOME/.bashrc"
    [ ! -e "$HOME/.local/share/bash-completion/completions/up" ]
    [ ! -e "$HOME/.zsh/completions/_up" ]
    [ ! -e "$HOME/.config/fish/completions/up.fish" ]
}

@test "uninstall: attack unreadable crontab, expected no rewrite of it" {
    cat >"$STUBS/crontab" <<'EOS'
#!/bin/bash
if [[ $1 == -l ]]; then echo "crontab: temporary read failure" >&2; exit 1; fi
cat >"$HOME/crontab-written"
EOS
    touch "$HOME/.bashrc"
    run bash "$REPO_DIR/uninstall.sh"
    [ ! -e "$HOME/crontab-written" ]
}

@test "uninstall: cron removal keeps unrelated lines that name emerger.sh" {
    printf '%s\n' '0 3 * * * /opt/backup/emerger.sh --sync' '0 10 * * 0 bash "/x/src/emerger.sh" -y -q -nl -ni' >"$HOME/crontab"
    touch "$HOME/.bashrc"
    run bash "$REPO_DIR/uninstall.sh"
    [ "$status" -eq 0 ]
    [ "$(cat "$HOME/crontab")" = '0 3 * * * /opt/backup/emerger.sh --sync' ]
}

@test "uninstall: removes the man page install.sh installed" {
    touch "$HOME/.bashrc"
    run env PATH="$STUBS:/usr/bin:/bin" bash "$REPO_DIR/install.sh"
    [ -e "$HOME/.local/share/man/man1/up.1" ]
    run bash "$REPO_DIR/uninstall.sh"
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/.local/share/man/man1/up.1" ]
}

# Run uninstall.sh on a pseudo-terminal, answering $1 to its question.
uninstall_answering() {
    mkdir -p "$XDG_CONFIG_HOME/emerger" "$HOME/.local/state/emerger" "$HOME/.cache/emerger"
    touch "$XDG_CONFIG_HOME/emerger/config.sh" "$HOME/.local/state/emerger/history.jsonl" "$HOME/.cache/emerger/detected" "$HOME/.bashrc"
    printf '%s\n' "$1" | script -qec "bash '$REPO_DIR/uninstall.sh'" /dev/null
}

@test "uninstall: answering y deletes settings, history and cache" {
    run uninstall_answering y
    [ "$status" -eq 0 ]
    [ ! -e "$XDG_CONFIG_HOME/emerger" ]
    [ ! -e "$HOME/.local/state/emerger" ]
    [ ! -e "$HOME/.cache/emerger" ]
    [[ "$output" != *"Remove manually"* ]]
}

@test "uninstall: answering n keeps settings, history and cache and says how to remove them" {
    run uninstall_answering n
    [ "$status" -eq 0 ]
    [ -e "$XDG_CONFIG_HOME/emerger/config.sh" ]
    [ -e "$HOME/.local/state/emerger/history.jsonl" ]
    [[ "$output" == *"Remove manually"* ]]
}

@test "uninstall: without a terminal keeps settings, history and cache" {
    mkdir -p "$XDG_CONFIG_HOME/emerger"; touch "$XDG_CONFIG_HOME/emerger/config.sh" "$HOME/.bashrc"
    run bash "$REPO_DIR/uninstall.sh" </dev/null
    [ "$status" -eq 0 ]
    [ -e "$XDG_CONFIG_HOME/emerger/config.sh" ]
    [[ "$output" == *"Remove manually"* ]]
}
