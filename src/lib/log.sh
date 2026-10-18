#!/usr/bin/env bash
# Structured logging to $EMERGER_LOG and its --errors viewer.

: "${EMERGER_STATE:=${XDG_STATE_HOME:-$HOME/.local/state}/emerger}"
: "${EMERGER_LOG:=$EMERGER_STATE/emerger.log}"

# Create the log readable by its owner only and keep its last 2000 lines.
log_init() {
    mkdir -p "$(dirname "$EMERGER_LOG")"
    touch "$EMERGER_LOG"
    # Failing managers' output lands here and may carry URLs or tokens.
    chmod 600 "$EMERGER_LOG" 2>/dev/null || true
    if [[ $(wc -l <"$EMERGER_LOG" 2>/dev/null || echo 0) -gt 2000 ]]; then
        tail -n 2000 "$EMERGER_LOG" >"${EMERGER_LOG}.tmp" && mv "${EMERGER_LOG}.tmp" "$EMERGER_LOG"
    fi
}

# Append "<UTC time>|<level $1>|<message $2...>" to EMERGER_LOG. A write
# failure is ignored.
_log() {
    local level="$1"; shift
    printf '%s|%s|%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$level" "$*" >>"$EMERGER_LOG" 2>/dev/null || true
}
# Log message $* at INFO, WARN or ERROR level.
log_info()  { _log INFO  "$@"; }
log_warn()  { _log WARN  "$@"; }
log_error() { _log ERROR "$@"; }

# Print the count of ERROR lines in EMERGER_LOG and the last 30 of them,
# highlighted, or that there are none.
log_show_errors() {
    local log="$EMERGER_LOG"
    if [[ ! -f $log ]]; then
        ui_ok "No log yet."
        return 0
    fi
    local count
    count=$(grep -c '|ERROR|' "$log" 2>/dev/null || true)
    : "${count:=0}"
    if (( count == 0 )); then
        ui_ok "No errors logged."
    else
        ui_warn "$count error line(s) in $log:"
        grep '|ERROR|' "$log" | tail -n 30 | ui_terminal_bytes | ui_highlight | sed 's/^/  /'
    fi
}
