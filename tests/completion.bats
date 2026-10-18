#!/usr/bin/env bats

load test_helper

setup() {
    setup_home
    export XDG_CONFIG_HOME="$HOME/.config"
    mkdir -p "$XDG_CONFIG_HOME/emerger/profiles.d"
}

teardown() {
    teardown_home
}

# Print the bash completions for the words given, one per line.
complete_words() {
    (cd "$HOME" && bash -c 'source "$1/completions/up.bash"
        alias up="bash \"$1/src/emerger.sh\""
        shift
        COMP_WORDS=("$@"); COMP_CWORD=$(( $# - 1 ))
        _up_completion
        printf "%s\n" "${COMPREPLY[@]}"' _ "$REPO_DIR" "$@")
}

@test "completion: --profile offers the shipped profiles" {
    run complete_words up --profile ""
    [ "$status" -eq 0 ]
    [[ "$output" == *home*safe*server*work* ]]
}

@test "completion: --profile treats a crafted file name as text, never runs it" {
    touch "$XDG_CONFIG_HOME/emerger/profiles.d/\$(touch pwned).sh"
    run complete_words up --profile ""
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/pwned" ]
    [[ "$output" == *'$(touch pwned)'* ]]
}

@test "completion: --profile filters by the typed prefix" {
    run complete_words up --profile se
    [ "$output" = "server" ]
}

@test "completion: zsh --profile offers the shipped profiles" {
    command -v zsh >/dev/null || skip "zsh not installed"
    mkdir -p "$HOME/.zsh/completions"; cp "$REPO_DIR/completions/_up" "$HOME/.zsh/completions/_up"
    run zsh -fc 'compdef() { :; }; compadd() { [[ $1 == -- ]] && shift; print -l -- "$@"; }
        source "$HOME/.zsh/completions/_up"
        alias up="bash \"$1/src/emerger.sh\""
        _up_profiles' _ "$REPO_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *home*safe*server*work* ]]
}

@test "completion: zsh lets -q repeat" {
    command -v zsh >/dev/null || skip "zsh not installed"
    # Capture the option specs _up hands to _arguments.
    run zsh -fc 'compdef() { :; }; _arguments() { print -l -- "$@"; }
        source "$1/completions/_up"; _up' _ "$REPO_DIR"
    [ "$status" -eq 0 ]
    printf '%s\n' "$output" | grep -q '^\*-q\['
}

@test "completion: zsh treats a crafted profile name as text, never runs it" {
    command -v zsh >/dev/null || skip "zsh not installed"
    touch "$XDG_CONFIG_HOME/emerger/profiles.d/a:m:{touch pwned}.sh"
    run zsh -fc 'compdef() { :; }; _values() { print -r -- "values $*"; }; compadd() { print -r -l -- "$@"; }
        cd "$HOME"; source "$1/completions/_up"; _up_profiles' _ "$REPO_DIR"
    [ "$status" -eq 0 ]
    [ ! -e "$HOME/pwned" ]
    [[ "$output" != *values* ]]
    [[ "$output" == *'a:m:{touch pwned}'* ]]
}

@test "completion: fish --profile offers the shipped profiles" {
    command -v fish >/dev/null || skip "fish not installed"
    mkdir -p "$HOME/.config/fish/completions"; cp "$REPO_DIR/completions/up.fish" "$HOME/.config/fish/completions/up.fish"
    run fish --no-config -c "source '$HOME/.config/fish/completions/up.fish'
        # What fish's alias builtin defines.
        function up; bash \"$REPO_DIR/src/emerger.sh\" \$argv; end
        __up_profiles"
    [ "$status" -eq 0 ]
    [[ "$output" == *home*safe*server*work* ]]
}

@test "completion: fish finds the shipped profiles through an unquoted alias" {
    command -v fish >/dev/null || skip "fish not installed"
    run fish --no-config -c "source '$REPO_DIR/completions/up.fish'
        function up; bash $REPO_DIR/src/emerger.sh \$argv; end
        __up_profiles"
    [[ "$output" == *home*safe*server*work* ]]
}

@test "completion: fish offers the single-dash aliases" {
    command -v fish >/dev/null || skip "fish not installed"
    run fish --no-config -c "source '$REPO_DIR/completions/up.fish'; complete -C 'up -'"
    for flag in -qq -qqq -up -au -rc -nl -err; do
        printf '%s\n' "$output" | grep -q -- "^$flag"$'\t' || { echo "missing $flag"; false; }
    done
}

@test "completion: --metrics offers a file name with a space as one word" {
    touch "$HOME/my metrics.prom"
    run complete_words up --metrics my
    [ "$status" -eq 0 ]
    [ "$output" = "my metrics.prom" ]
}

@test "completion: --profile lists a name once when the user and shipped directories both hold it" {
    touch "$XDG_CONFIG_HOME/emerger/profiles.d/safe.sh" "$XDG_CONFIG_HOME/emerger/profiles.d/safeX.sh"
    run complete_words up --profile saf
    [ "$status" -eq 0 ]
    [ "$(printf '%s\n' "$output" | grep -cx safe)" -eq 1 ]
    [[ "$output" == *safeX* ]]
}

@test "completion: the bash file uses no associative array, mapfile or readarray (bash 3.2)" {
    run bash -c "grep -vE '^[[:space:]]*#' \"\$1\" | grep -nE 'local -A|declare -A|typeset -A|\\bmapfile\\b|\\breadarray\\b'" _ "$REPO_DIR/completions/up.bash"
    [ "$status" -eq 1 ]
}

@test "completion: --metrics keeps a backslash in a file name" {
    touch "$HOME/a\\b.csv"
    run complete_words up --metrics "a"
    [ "$status" -eq 0 ]
    [ "$output" = 'a\b.csv' ]
}

@test "completion: --profile finds the shipped profiles without BASH_ALIASES, as on bash 3.2" {
    run bash -c 'unset BASH_ALIASES; source "$1/completions/up.bash"
        alias up="bash \"$1/src/emerger.sh\""
        COMP_WORDS=(up --profile ""); COMP_CWORD=2
        _up_completion
        printf "%s\n" "${COMPREPLY[@]}"' _ "$REPO_DIR"
    [ "$status" -eq 0 ]
    [[ "$output" == *home*safe*server*work* ]]
}
