#!/usr/bin/env bash
# Global lock: prevent two concurrent eMerger runs from stepping on each other.

: "${EMERGER_LOCK:=${XDG_RUNTIME_DIR:-${EMERGER_STATE:-${XDG_STATE_HOME:-$HOME/.local/state}/emerger}}/emerger.lock}"

lock_acquire() {
    exec 9>"$EMERGER_LOCK" 2>/dev/null || return 0
    if ! command -v flock >/dev/null 2>&1; then
        return 0
    fi
    if ! flock -n 9; then
        ui_err "Another eMerger run is in progress (lock: $EMERGER_LOCK)."
        ui_muted "Wait for it, or remove the lock file if you're sure it's stale."
        return 1
    fi
    printf '%d\n' "$$" >&9
    return 0
}

lock_release() {
    exec 9>&- 2>/dev/null || true
}
