#!/usr/bin/env bash
# Structured logging to $EMERGER_LOG.

: "${EMERGER_STATE:=${XDG_STATE_HOME:-$HOME/.local/state}/emerger}"
: "${EMERGER_LOG:=$EMERGER_STATE/emerger.log}"

log_init() {
    mkdir -p "$(dirname "$EMERGER_LOG")"
    touch "$EMERGER_LOG"
    if [[ $(wc -l <"$EMERGER_LOG" 2>/dev/null || echo 0) -gt 2000 ]]; then
        tail -n 2000 "$EMERGER_LOG" >"${EMERGER_LOG}.tmp" && mv "${EMERGER_LOG}.tmp" "$EMERGER_LOG"
    fi
}

_log() {
    local level="$1"; shift
    printf '%s|%s|%s\n' "$(date -u '+%Y-%m-%dT%H:%M:%SZ')" "$level" "$*" >>"$EMERGER_LOG" 2>/dev/null || true
}
log_info()  { _log INFO  "$@"; }
log_warn()  { _log WARN  "$@"; }
log_error() { _log ERROR "$@"; }
