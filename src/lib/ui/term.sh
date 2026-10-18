#!/usr/bin/env bash
# Terminal capabilities: colour, UTF-8 and emoji detection, glyphs, width,
# cursor.
# UI_* are read by the other ui modules.
# shellcheck disable=SC2034

: "${ARG_ASCII:=0}"
: "${EMERGER_EMOJI:=auto}"          # auto, 1 or 0

# Set UI_IS_LIGHT_BG to 1 when COLORFGBG names a background colour of 7 or
# more, else 0.
_ui_detect_light_bg() {
    # COLORFGBG is "fg;bg": a background of 0 to 6 is a dark theme, 7 or more a light one.
    [[ -z ${COLORFGBG:-} ]] && { UI_IS_LIGHT_BG=0; return; }
    local background="${COLORFGBG##*;}"
    if [[ $background =~ ^[0-9]+$ ]] && (( background >= 7 )); then
        UI_IS_LIGHT_BG=1
    else
        UI_IS_LIGHT_BG=0
    fi
}

# Set UI_HAS_EMOJI: EMERGER_EMOJI when it says yes or no, else 1 on macOS, over
# SSH or with a colour-emoji font installed. Always 0 without UTF-8, where
# emoji would show as empty boxes.
_ui_detect_emoji() {
    UI_HAS_EMOJI=0
    (( UI_HAS_UNICODE )) || return 0
    case "${EMERGER_EMOJI,,}" in
        1|yes|on|true)   UI_HAS_EMOJI=1; return 0 ;;
        0|no|off|false)  return 0 ;;
    esac
    [[ ${TERM:-} == linux ]] && return 0
    [[ ${OSTYPE:-} == darwin* ]] && { UI_HAS_EMOJI=1; return 0; }
    # Over SSH the client's fonts matter.
    [[ -n ${SSH_CONNECTION:-} ]] && { UI_HAS_EMOJI=1; return 0; }
    if command -v fc-list >/dev/null 2>&1; then
        [[ -n $(fc-list ':charset=1f4e6' family 2>/dev/null | head -n 1) ]] && UI_HAS_EMOJI=1
    fi
    return 0
}

# Set the colour codes, gradient and UI_IS_TTY from the terminal, NO_COLOR
# and TERM, then UI_HAS_UNICODE from --ascii and the locale, and UI_HAS_EMOJI.
_ui_init() {
    local colors=0
    _ui_detect_light_bg
    if [[ -n ${NO_COLOR:-} ]] || [[ ${TERM:-} == dumb ]] || ! [[ -t 1 ]]; then
        C_RESET="" C_BOLD="" C_DIM=""
        C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_MAGENTA="" C_CYAN="" C_GRAY=""
        UI_GRADIENT=()
        UI_IS_TTY=0
    else
        command -v tput >/dev/null 2>&1 && colors=$(tput colors 2>/dev/null || echo 0)
        C_RESET=$'\e[0m'; C_BOLD=$'\e[1m'; C_DIM=$'\e[2m'
        if (( colors >= 256 )); then
            if (( UI_IS_LIGHT_BG )); then
                C_RED=$'\e[38;5;160m'; C_GREEN=$'\e[38;5;28m'; C_YELLOW=$'\e[38;5;136m'
                C_BLUE=$'\e[38;5;26m'; C_MAGENTA=$'\e[38;5;90m'; C_CYAN=$'\e[38;5;30m'
                C_GRAY=$'\e[38;5;240m'
                UI_GRADIENT=(35 35 29 29 29 22 22)
            else
                C_RED=$'\e[38;5;203m'; C_GREEN=$'\e[38;5;114m'; C_YELLOW=$'\e[38;5;221m'
                C_BLUE=$'\e[38;5;39m';  C_MAGENTA=$'\e[38;5;176m'; C_CYAN=$'\e[38;5;81m'
                C_GRAY=$'\e[38;5;245m'
                UI_GRADIENT=(121 84 48 42 35 29 29)
            fi
        else
            C_RED=$'\e[31m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'
            C_BLUE=$'\e[34m'; C_MAGENTA=$'\e[35m'; C_CYAN=$'\e[36m'; C_GRAY=$'\e[37m'
            UI_GRADIENT=()
        fi
        UI_IS_TTY=1
    fi
    # Read as text: the value may come from the environment, where arithmetic
    # would run it as code.
    if [[ ${ARG_ASCII:-0} =~ ^[0-9]{1,15}$ ]] && (( 10#$ARG_ASCII )); then
        UI_HAS_UNICODE=0
    # The first set of LC_ALL, LC_CTYPE and LANG decides the character set.
    elif [[ ${LC_ALL:-${LC_CTYPE:-${LANG:-}}} =~ [Uu][Tt][Ff]-?8 ]]; then
        UI_HAS_UNICODE=1
    else
        UI_HAS_UNICODE=0
    fi
    _ui_detect_emoji
}
_ui_init

# Detect the terminal again, after a flag, config or profile changed what
# _ui_init reads.
ui_reinit() { _ui_init; }

# Print glyph name $1 (check, cross, arrow, box corners...) as Unicode, or
# its ASCII stand-in when UI_HAS_UNICODE is 0. Unknown names print nothing.
ui_glyph() {
    if (( UI_HAS_UNICODE )); then
        case "$1" in
            check)   printf '\xe2\x9c\x94' ;;
            cross)   printf '\xe2\x9c\x96' ;;
            arrow)   printf '\xe2\x96\xb8' ;;
            info)    printf '\xe2\x97\x8f' ;;
            warn)    printf '\xe2\x96\xb2' ;;
            ask)     printf '\xe2\x9d\xaf' ;;
            bullet)  printf '\xe2\x80\xa2' ;;
            hline)   printf '\xe2\x94\x80' ;;
            dot)     printf '\xc2\xb7' ;;
            diamond) printf '\xe2\x97\x86' ;;
            pfull)   printf '\xe2\x96\xb0' ;;
            pempty)  printf '\xe2\x96\xb1' ;;
            tl) printf '\xe2\x95\xad' ;;
            tr) printf '\xe2\x95\xae' ;;
            bl) printf '\xe2\x95\xb0' ;;
            br) printf '\xe2\x95\xaf' ;;
            v)  printf '\xe2\x94\x82' ;;
        esac
    else
        case "$1" in
            check)   printf '[OK]' ;;
            cross)   printf '[X]' ;;
            arrow)   printf '>' ;;
            info)    printf 'i' ;;
            warn)    printf '!' ;;
            ask)     printf '?' ;;
            bullet)  printf '*' ;;
            hline)   printf '-' ;;
            dot)     printf '.' ;;
            diamond) printf '*' ;;
            pfull)   printf '#' ;;
            pempty)  printf '.' ;;
            tl|tr|bl|br) printf '+' ;;
            v) printf '|' ;;
        esac
    fi
}

# Print the terminal width in columns, 80 when tput cannot tell.
ui_width() {
    local width
    width=$(tput cols 2>/dev/null || echo 80)
    (( width > 0 )) || width=80
    printf '%d' "$width"
}

# Print the width for headers and boxes: the terminal width held between 40
# and 78 columns.
_ui_columns() {
    local width; width=$(ui_width)
    (( width > 78 )) && width=78
    (( width < 40 )) && width=40
    printf '%d' "$width"
}

# Hide or show the cursor on a terminal. Always return 0.
ui_cursor_hide() { (( UI_IS_TTY )) && printf '\e[?25l'; return 0; }
ui_cursor_show() { (( UI_IS_TTY )) && printf '\e[?25h'; return 0; }
