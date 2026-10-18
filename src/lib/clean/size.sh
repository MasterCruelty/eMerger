#!/usr/bin/env bash
# Size of a path on disk and its short human-readable form.

# Print the size of path $1 in KiB, 0 when it is missing. du exits non-zero
# on any unreadable entry: its partial total is still the best figure.
_clean_size_kb() {
    [[ -e "$1" ]] || { echo 0; return; }
    { du -sk "$1" 2>/dev/null || true; } | awk 'NR == 1 { n = $1 + 0 } END { print n + 0 }'
}

# Print the human-readable size of path $1, empty when du prints nothing.
_clean_size_human() {
    { du -sh "$1" 2>/dev/null || true; } | cut -f1
}

# Print KiB count $1 as 1.5G, 42M or 512K (G with one decimal, M and K
# whole, rounded down).
_clean_format_kb() {
    local kb="$1"
    if (( kb >= 1048576 )); then
        printf '%d.%dG' $(( kb / 1048576 )) $(( kb % 1048576 * 10 / 1048576 ))
    elif (( kb >= 1024 )); then
        printf '%dM' $(( kb / 1024 ))
    else
        printf '%dK' "$kb"
    fi
}
