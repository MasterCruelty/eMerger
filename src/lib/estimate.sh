#!/usr/bin/env bash
# Estimate step duration based on recent history.jsonl entries.

estimate_for() {
    local mgr="$1"
    local hist="$EMERGER_STATE/history.jsonl"
    [[ -f $hist ]] || { printf ''; return; }
    # Crude: average run duration over last 5 runs that included this manager.
    tail -n 20 "$hist" 2>/dev/null | awk -v m="\"$mgr\"" '
        index($0, m) > 0 {
            match($0, /"duration":[0-9]+/)
            if (RLENGTH > 0) {
                d = substr($0, RSTART+11, RLENGTH-11)
                sum += d; n += 1
            }
        }
        END {
            if (n > 0) printf "~%ds", int(sum/n)
        }
    '
}
