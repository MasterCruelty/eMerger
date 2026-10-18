#!/usr/bin/env bash
# Prompts on the terminal: free answer and yes/no.

: "${EMERGER_PROMPT_TIMEOUT:=60}"   # seconds, 0 waits forever

# Ask prompt $1 with hint $2 and detail $3 on /dev/tty, which works with stdin
# or stderr redirected. Set UI_ANSWER and return 1 when nothing was read (no
# tty, EOF, EMERGER_PROMPT_TIMEOUT), so the caller tells a default from an answer.
ui_ask() {
    local prompt="$1" hint="${2:-}" detail="${3:-}" fd timeout="${EMERGER_PROMPT_TIMEOUT:-60}"
    [[ $timeout =~ ^[0-9]{1,9}$ ]] && timeout=$(( 10#$timeout )) || timeout=60
    UI_ANSWER=""
    if ! { exec {fd}<>/dev/tty; } 2>/dev/null; then
        ui_muted "no terminal for \"$prompt\", using the default"
        return 1
    fi
    printf '    %s%s%s %s%s%s' "$C_MAGENTA$C_BOLD" "$(ui_glyph ask)" "$C_RESET" "$C_BOLD" "$prompt" "$C_RESET" >&"$fd"
    [[ -n $detail ]] && printf ' %s%s%s' "$C_DIM$C_GRAY" "$detail" "$C_RESET" >&"$fd"
    [[ -n $hint ]]   && printf ' %s[%s]%s' "$C_GRAY" "$hint" "$C_RESET" >&"$fd"
    printf ' ' >&"$fd"
    local rc=0
    if (( timeout > 0 )); then
        read -r -t "$timeout" -u "$fd" UI_ANSWER || rc=$?
    else
        read -r -u "$fd" UI_ANSWER || rc=$?
    fi
    if (( rc != 0 )); then
        printf '\n' >&"$fd"
        UI_ANSWER=""
        # read -t exits >128 on timeout, 1 on EOF.
        if (( rc > 128 )); then
            ui_muted "no answer after ${timeout}s, using the default"
        else
            ui_muted "no input, using the default"
        fi
        rc=1
    fi
    exec {fd}>&-
    return "$rc"
}

# Ask y/N question $1 (default answer $2, detail $3) and return 0 for yes.
# -y says yes without asking.
ui_confirm() {
    local prompt="$1" default="${2:-n}" detail="${3:-}"
    if (( ${ARG_YES:-0} )); then return 0; fi
    local hint="y/N"; [[ $default == [yY]* ]] && hint="Y/n"
    ui_ask "$prompt" "$hint" "$detail" || true
    local answer=${UI_ANSWER:-$default}
    [[ $answer == [yY]* ]]
}
