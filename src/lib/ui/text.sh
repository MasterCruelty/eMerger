#!/usr/bin/env bash
# Text measurement and filtering: escape stripping, visible width, repeat,
# percentage bar, stream highlighting.

# Helpers named _ui_* return through globals to avoid subshells.

# Set _UI_STRIPPED to text $1 without its CSI escape sequences.
_ui_strip() {
    local text="$1" re=$'\e''\[[0-9;?]*[a-zA-Z]'
    while [[ $text =~ $re ]]; do text=${text/"${BASH_REMATCH[0]}"/}; done
    _UI_STRIPPED="$text"
}

# Set _UI_WIDTH to the visible width of $1, escapes stripped, emoji counted
# as two columns.
_ui_visible_width() {
    _ui_strip "$1"
    local text="$_UI_STRIPPED" width=${#_UI_STRIPPED} i char
    if (( UI_HAS_EMOJI )); then
        for (( i=0; i<${#text}; i++ )); do
            char=${text:i:1}
            [[ $char == [[:ascii:]] ]] && continue
            (( $(printf '%d' "'$char") >= 0x1F000 )) && width=$(( width + 1 ))
        done
    fi
    _UI_WIDTH=$width
}

# Set _UI_REPEATED to string $1 repeated $2 times.
_ui_repeat() {
    local line; printf -v line '%*s' "$2" ''
    _UI_REPEATED=${line// /$1}
}

# Set _UI_BAR to a 10-column coloured bar for percentage $1, clamped to
# 0 to 100. Unicode fills in eighths of a cell.
ui_bar() {
    local percent="$1" width=10 full=0 remainder=0 i bar="" empty="" fill='#' pad='-'
    (( percent < 0 )) && percent=0
    (( percent > 100 )) && percent=100
    if (( UI_HAS_UNICODE )); then
        local parts=('' '▏' '▎' '▍' '▌' '▋' '▊' '▉')
        fill='█'; pad='░'
        full=$(( percent * width * 8 / 100 / 8 )); remainder=$(( percent * width * 8 / 100 % 8 ))
        for (( i=0; i<full; i++ )); do bar+=$fill; done
        (( remainder > 0 && full < width )) && { bar+=${parts[remainder]}; full=$(( full + 1 )); }
    else
        full=$(( percent * width / 100 ))
        for (( i=0; i<full; i++ )); do bar+=$fill; done
    fi
    for (( i=full; i<width; i++ )); do empty+="$pad"; done
    _UI_BAR="${C_GREEN}${bar}${C_RESET}${C_DIM}${C_GRAY}${empty}${C_RESET}"
}

# Remove from line $1 what a terminal would act on: everything up to the last
# carriage return, CSI and OSC sequences, stray control bytes and C1 controls
# (UTF-8 C2 80 to C2 9F). Result in _UI_CLEANED, cut to 1024 characters first:
# each removal copies the line, so the cost grows with the square of its length.
_ui_clean_line() {
    local LC_ALL line="$1" re_csi=$'\e''\[[0-9;?]*[a-zA-Z]'
    local re_osc=$'\e\\][^\a\e]*(\a|\e\\\\)?' re_control=$'[\x01-\x08\x0b-\x1f\x7f]'
    # A line over 4096 bytes is shown from 4096 bytes before its end: the \r
    # cut below scans in time growing with the square of the length.
    (( ${#line} > 4096 )) && line=${line: -4096}
    line=${line##*$'\r'}
    line=${line:0:1024}
    LC_ALL=C   # byte-wise from here, so the C1 pair matches whatever the locale
    while [[ $line =~ $re_csi ]]; do line=${line/"${BASH_REMATCH[0]}"/}; done
    # OSC (title, clipboard, hyperlink) and stray controls never reach the terminal.
    while [[ $line =~ $re_osc ]]; do line=${line/"${BASH_REMATCH[0]}"/}; done
    line=${line//$re_control/}
    # Removing one C1 pair or control byte can join the halves of another: repeat.
    while [[ $line == *$'\xc2'[$'\x80'-$'\x9f']* ]]; do
        line=${line//$'\xc2'[$'\x80'-$'\x9f']/}
    done
    # A terminal outside UTF-8 reads a byte in 0x80-0x9F as a C1 control.
    (( ${UI_HAS_UNICODE:-0} )) || line=${line//[$'\x80'-$'\xff']/}
    _UI_CLEANED=$line
}

# Copy stdin to stdout with error words in red and warning words in yellow,
# apt "E:" and "W:" lines whole. With colours off (NO_COLOR, dumb terminal,
# no tty) the stream is copied unchanged.
ui_highlight() {
    [[ -n ${C_RED:-} ]] || { cat; return; }
    sed -E \
        -e "s/(ERROR|Error|error)/$(printf '\033[31m')\1$(printf '\033[0m')/g" \
        -e "s/(WARNING|Warning|warning|WARN)/$(printf '\033[33m')\1$(printf '\033[0m')/g" \
        -e "s/^(E: .*)/$(printf '\033[31m')\1$(printf '\033[0m')/g" \
        -e "s/^(W: .*)/$(printf '\033[33m')\1$(printf '\033[0m')/g"
}

# Copy stdin to stdout, dropping every byte above 0x7F when the terminal is
# not UTF-8: such a terminal reads 0x80-0x9F as C1 controls.
ui_terminal_bytes() {
    if (( ${UI_HAS_UNICODE:-0} )); then
        cat
    else
        LC_ALL=C tr -d '\200-\377'
    fi
}
