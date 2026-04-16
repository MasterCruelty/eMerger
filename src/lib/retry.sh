#!/usr/bin/env bash
# Retry a command with exponential backoff on transient failures.
# Detects network errors by scanning output for common keywords.

retry_cmd() {
    local max="${1:-3}"; shift
    local attempt=1 rc=0
    while :; do
        "$@"
        rc=$?
        (( rc == 0 )) && return 0
        if (( attempt >= max )); then return "$rc"; fi
        local backoff=$(( attempt * 3 ))
        log_warn "retry attempt $attempt/$max for: $* (sleeping ${backoff}s)"
        sleep "$backoff"
        attempt=$(( attempt + 1 ))
    done
}

# Pattern tester: returns 0 if output looks like a transient network failure.
retry_is_transient() {
    local text="$1"
    local pat='(Temporary failure|Could not resolve|Connection (timed out|reset|refused)|network is unreachable|503 |502 |504 |failed to fetch|EOF occurred|timed out|Try again later)'
    [[ $text =~ $pat ]]
}
