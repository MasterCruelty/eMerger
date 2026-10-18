#!/usr/bin/env bash
# Estimate step duration based on recent history.jsonl entries.

# Print the average time manager $1 took over the last 10 runs, as "~42s" or
# "~9m30s", from each run's per-manager "secs". Print nothing without data.
estimate_for() {
    local manager="$1"
    local history="$EMERGER_STATE/history.jsonl"
    [[ -f $history ]] || return 0
    tail -n 10 "$history" 2>/dev/null | awk -v key="\"name\":\"$manager\"," '
        {
            line = $0
            while ((p = index(line, key)) > 0) {
                line = substr(line, p + length(key))
                obj = substr(line, 1, index(line "}", "}") - 1)
                if (match(obj, /"secs":[0-9]+/)) {
                    d = substr(obj, RSTART + 7, RLENGTH - 7) + 0
                    if (d > 0) { sum += d; n += 1 }
                }
            }
        }
        END {
            if (n == 0) exit
            avg = int(sum / n + 0.5)
            if (avg < 60) printf "~%ds", avg
            else printf "~%dm%02ds", int(avg / 60), avg % 60
        }
    '
}
