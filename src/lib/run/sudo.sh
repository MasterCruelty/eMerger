#!/usr/bin/env bash
# sudo timestamp keep-alive for the length of the run.

# Start the background loop that refreshes the sudo timestamp every $1
# seconds (default 60), its PID in SUDO_KEEPALIVE_PID. The loop holds no
# terminal or pipe open, ends with its parent (checked by parent PID, so a
# reused PID does not keep it alive) and takes its sleep with it on TERM.
run_sudo_keepalive() {
    local interval="${1:-60}"
    (
        exec </dev/null >/dev/null 2>&1
        sleep_pid=0
        trap 'kill "$sleep_pid" 2>/dev/null; exit 0' TERM
        while sys_is_parent_alive "$$"; do
            sudo -n true
            sleep "$interval" & sleep_pid=$!
            wait "$sleep_pid"
        done
    ) 9>&- &
    SUDO_KEEPALIVE_PID=$!
    disown "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
}
