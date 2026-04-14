#!/usr/bin/env bash
# Command runner: dry-run aware, live-log monitor, retry on transient errors,
# one-line collapsed summary on success.

: "${DRY_RUN:=0}"
: "${UI_VERBOSE:=0}"
: "${RETRY_MAX:=2}"

run_cmd() {
    local label="$1"; shift
    if (( DRY_RUN )); then
        local joined; joined=$(IFS=' '; printf '%s' "$*")
        ui_sub "[dry-run] $joined"
        return 0
    fi
    local rc=0
    if (( UI_VERBOSE )); then
        ui_sub "$label"
        "$@"
        rc=$?
        if (( rc == 0 )); then
            return 0
        else
            ui_fail "$label" "$rc"
            log_error "$label: rc=$rc"
            return "$rc"
        fi
    fi

    local tmp; tmp=$(mktemp -t emerger.XXXXXX)
    trap 'rm -f "$tmp"' RETURN
    local attempt=1
    while :; do
        : >"$tmp"
        ui_monitor_start "$label" "$tmp"
        "$@" >"$tmp" 2>&1
        rc=$?
        ui_monitor_stop
        if (( rc == 0 )); then
            local stat=""
            stat=$(progress_summarize "${_PKG_CURRENT:-}" "$tmp")
            if [[ -n $stat ]]; then
                ui_done "$label" "$stat"
            else
                ui_done "$label"
            fi
            rm -f "$tmp"
            return 0
        fi
        local out; out=$(cat "$tmp" 2>/dev/null || true)
        if retry_is_transient "$out" && (( attempt < RETRY_MAX )); then
            ui_warn "$label: transient failure, retrying ($attempt/$RETRY_MAX)"
            log_warn "$label: retry $attempt (rc=$rc)"
            attempt=$(( attempt + 1 ))
            sleep $(( attempt * 2 ))
            continue
        fi
        ui_fail "$label" "$rc"
        log_error "$label: rc=$rc"
        tail -n 20 "$tmp" | progress_highlight >&2
        log_error "$(tail -n 50 "$tmp")"
        rm -f "$tmp"
        return "$rc"
    done
}
