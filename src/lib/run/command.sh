#!/usr/bin/env bash
# Command runner: dry-run aware, live-log monitor, retry on transient errors,
# one-line collapsed summary on success.

: "${DRY_RUN:=0}"
: "${UI_VERBOSE:=0}"
: "${RETRY_ATTEMPTS:=2}"
# Seconds before the first retry, the n-th retry waits n times as long.
: "${RETRY_DELAY:=3}"
# Seconds one command may run before it is stopped, 0 for no limit.
: "${MANAGER_TIMEOUT:=0}"

# Capture file of the command running now, removed by run_cmd_cleanup.
_RUN_TMP=""

# Set _RUN_TIMEOUT_PREFIX to the prefix that bounds a command by MANAGER_TIMEOUT (empty
# when there is no limit or no `timeout`, which is warned about once). Probed
# once per run: call it in the current shell, never in a subshell.
_run_timeout_prefix() {
    _RUN_TIMEOUT_PREFIX=()
    (( MANAGER_TIMEOUT > 0 )) || return 0
    if [[ -z ${_RUN_TIMEOUT_MODE:-} ]]; then
        _RUN_TIMEOUT_MODE=none
        if command -v timeout >/dev/null 2>&1; then
            # --foreground keeps a sudo password prompt on the terminal.
            if timeout --foreground 5 true 2>/dev/null; then
                _RUN_TIMEOUT_MODE="fg"
            else
                _RUN_TIMEOUT_MODE="plain"
            fi
        else
            ui_warn "MANAGER_TIMEOUT=$MANAGER_TIMEOUT is not applied: no timeout command found"
        fi
    fi
    case $_RUN_TIMEOUT_MODE in
        fg)    _RUN_TIMEOUT_PREFIX=(timeout --foreground -k 10 "$MANAGER_TIMEOUT") ;;
        plain) _RUN_TIMEOUT_PREFIX=(timeout "$MANAGER_TIMEOUT") ;;
    esac
    return 0
}

# Remove the capture file of an interrupted run_cmd. Called by the exit trap.
run_cmd_cleanup() {
    [[ -n $_RUN_TMP ]] && rm -f "$_RUN_TMP"
    _RUN_TMP=""
    return 0
}

# Strip terminal control sequences from stdin: CSI and OSC sequences whole,
# C0 controls except tab and newline, invalid UTF-8 and C1 controls. With $1
# set to `log` the text is bound for a file and keeps valid UTF-8; otherwise
# it is bound for the terminal and loses bytes above 0x7F on one outside UTF-8.
run_sanitize() {
    local target="${1:-terminal}"
    # Escape sequences, then control bytes, then invalid UTF-8 (iconv -c), so
    # the C1 pairs left are whole characters: removing them in one pass cannot
    # join the halves of another, since 0xC2 only ever starts a character.
    LC_ALL=C sed -E -e $'s/\x1b\\[[0-9;?]*[a-zA-Z]//g' -e $'s/\x1b\\][^\x07\x1b]*(\x07|\x1b\\\\)?//g' \
        | LC_ALL=C tr -d '\000-\010\013-\037\177' \
        | _run_valid_utf8 \
        | LC_ALL=C sed -e $'s/\xc2[\x80-\x9f]//g' \
        | if [[ $target == log ]]; then cat; else ui_terminal_bytes; fi
}


# Copy stdin to stdout without invalid UTF-8. Without iconv, drop every byte
# in 0x80-0x9F instead: no C1 control survives, at the cost of the non-ASCII
# characters holding such a byte.
_run_valid_utf8() {
    if command -v iconv >/dev/null 2>&1; then
        iconv -c -f UTF-8 -t UTF-8 2>/dev/null || true
    else
        LC_ALL=C tr -d '\200-\237'
    fi
}

# Return 0 when command output $1 reads as a transient network failure,
# which run_cmd retries.
retry_is_transient() {
    local text="$1"
    local pattern='(Temporary failure|Could not resolve|Connection (timed out|reset|refused)|network is unreachable|503 |502 |504 |failed to fetch|EOF occurred|timed out|Try again later)'
    [[ $text =~ $pattern ]]
}

# Run command "$@" under label $1: dry-run aware, retried on transient
# errors, bounded by MANAGER_TIMEOUT. Return the command's exit code (124
# on timeout). The command never inherits the lock fd 9.
run_cmd() {
    local label="$1"; shift
    if (( DRY_RUN )); then
        local joined; joined=$(IFS=' '; printf '%s' "$*")
        ui_sub "[dry-run] $joined"
        return 0
    fi
    if (( UI_VERBOSE )); then
        _run_cmd_verbose "$label" "$@"
        return
    fi
    _run_cmd_captured "$label" "$@"
}

# Run command $2... under label $1 for run_cmd under -v: output straight to
# the terminal (stderr under --json), no retry.
_run_cmd_verbose() {
    local label="$1"; shift
    local rc=0
    ui_sub "$label"
    local -a timeout_prefix=()
    declare -F "$1" >/dev/null || { _run_timeout_prefix; timeout_prefix=(${_RUN_TIMEOUT_PREFIX[@]+"${_RUN_TIMEOUT_PREFIX[@]}"}); }
    # Under --json, stdout carries the JSON object alone.
    local out_fd=1
    (( ${ARG_JSON:-0} )) && out_fd=2
    ${timeout_prefix[@]+"${timeout_prefix[@]}"} "$@" 9>&- >&"$out_fd"
    rc=$?
    (( rc == 124 && ${#timeout_prefix[@]} > 0 )) && ui_warn "$label: timed out after ${MANAGER_TIMEOUT}s"
    if (( rc == 0 )); then
        return 0
    else
        ui_fail "$label" "$rc"
        log_error "$label: rc=$rc"
        return "$rc"
    fi
}

# Run command $2... under label $1 for run_cmd without -v: output captured
# under the live monitor, retried on transient failures, its tail shown on failure.
_run_cmd_captured() {
    local label="$1"; shift
    local rc=0
    local capture
    if ! capture=$(mktemp -t emerger.XXXXXX 2>/dev/null); then
        # Read by ui_done.
        # shellcheck disable=SC2034
        UI_LAST_ELAPSED=""
        ui_fail "$label" 1
        ui_err "$label: cannot create a temp file in ${TMPDIR:-/tmp}"
        log_error "$label: cannot create a temp file in ${TMPDIR:-/tmp}"
        return 1
    fi
    _RUN_TMP=$capture
    local -a timeout_prefix=()
    # `timeout` runs programs only: a shell function runs unbounded.
    declare -F "$1" >/dev/null || { _run_timeout_prefix; timeout_prefix=(${_RUN_TIMEOUT_PREFIX[@]+"${_RUN_TIMEOUT_PREFIX[@]}"}); }
    local attempt=1
    while :; do
        : >"$capture"
        ui_monitor_start "$label" "$capture"
        ${timeout_prefix[@]+"${timeout_prefix[@]}"} "$@" >"$capture" 2>&1 9>&-
        rc=$?
        ui_monitor_stop
        if (( rc == 124 && ${#timeout_prefix[@]} > 0 )); then
            ui_warn "$label: timed out after ${MANAGER_TIMEOUT}s"
            log_error "$label: timed out after ${MANAGER_TIMEOUT}s"
        fi
        if (( rc == 0 )); then
            local summary=""
            summary=$(progress_summarize "${_PKG_CURRENT:-}" "$capture")
            if [[ -n $summary ]]; then
                ui_done "$label" "$summary"
            else
                ui_done "$label"
            fi
            rm -f "$capture"; _RUN_TMP=""
            return 0
        fi
        local output; output=$(cat "$capture" 2>/dev/null || true)
        if retry_is_transient "$output" && (( attempt < RETRY_ATTEMPTS )); then
            ui_warn "$label: transient failure, retrying ($attempt/$RETRY_ATTEMPTS)"
            log_warn "$label: retry $attempt (rc=$rc)"
            sleep $(( RETRY_DELAY * attempt ))
            attempt=$(( attempt + 1 ))
            continue
        fi
        ui_fail "$label" "$rc"
        log_error "$label: rc=$rc"
        tail -n 20 "$capture" | run_sanitize | ui_highlight | sed "s/^/      ${C_DIM}${C_GRAY}$(ui_glyph v)${C_RESET} /" >&2
        # No escape and no "|" in the log: output cannot forge a log line.
        log_error "$(tail -n 50 "$capture" | run_sanitize log | tr '|' '/')"
        rm -f "$capture"; _RUN_TMP=""
        return "$rc"
    done
}
