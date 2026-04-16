#!/usr/bin/env bash
# UI primitives: colors, glyphs, boxes, steps, live log monitor, box banner.

: "${ARG_NO_EMOJI:=0}"
: "${QUIET_LEVEL:=0}"

_ui_detect_light_bg() {
    # Parse COLORFGBG="fg;bg". A low bg value (0-6) = dark theme, 7+ = light.
    [[ -z ${COLORFGBG:-} ]] && { UI_LIGHT_BG=0; return; }
    local bg="${COLORFGBG##*;}"
    if [[ $bg =~ ^[0-9]+$ ]] && (( bg >= 7 )); then
        UI_LIGHT_BG=1
    else
        UI_LIGHT_BG=0
    fi
}

_ui_init() {
    local colors=0
    _ui_detect_light_bg
    if [[ -n ${NO_COLOR:-} ]] || [[ ${TERM:-} == dumb ]] || ! [[ -t 1 ]]; then
        C_RESET="" C_BOLD="" C_DIM=""
        C_RED="" C_GREEN="" C_YELLOW="" C_BLUE="" C_MAGENTA="" C_CYAN="" C_GRAY=""
        UI_TTY=0
    else
        command -v tput >/dev/null 2>&1 && colors=$(tput colors 2>/dev/null || echo 0)
        C_RESET=$'\e[0m'; C_BOLD=$'\e[1m'; C_DIM=$'\e[2m'
        if (( colors >= 256 )); then
            if (( UI_LIGHT_BG )); then
                C_RED=$'\e[38;5;160m'; C_GREEN=$'\e[38;5;28m'; C_YELLOW=$'\e[38;5;136m'
                C_BLUE=$'\e[38;5;26m'; C_MAGENTA=$'\e[38;5;90m'; C_CYAN=$'\e[38;5;30m'
                C_GRAY=$'\e[38;5;240m'
            else
                C_RED=$'\e[38;5;203m'; C_GREEN=$'\e[38;5;114m'; C_YELLOW=$'\e[38;5;221m'
                C_BLUE=$'\e[38;5;39m';  C_MAGENTA=$'\e[38;5;176m'; C_CYAN=$'\e[38;5;81m'
                C_GRAY=$'\e[38;5;245m'
            fi
        else
            C_RED=$'\e[31m'; C_GREEN=$'\e[32m'; C_YELLOW=$'\e[33m'
            C_BLUE=$'\e[34m'; C_MAGENTA=$'\e[35m'; C_CYAN=$'\e[36m'; C_GRAY=$'\e[37m'
        fi
        UI_TTY=1
    fi
    if (( ARG_NO_EMOJI )); then
        UI_UNICODE=0
    elif [[ ${LANG:-} =~ [Uu][Tt][Ff]-?8 ]] || [[ ${LC_ALL:-} =~ [Uu][Tt][Ff]-?8 ]] || [[ ${LC_CTYPE:-} =~ [Uu][Tt][Ff]-?8 ]]; then
        UI_UNICODE=1
    else
        UI_UNICODE=0
    fi
}
_ui_init

ui_reinit() { _ui_init; }

ui_glyph() {
    if (( UI_UNICODE )); then
        case "$1" in
            check)  printf '\xe2\x9c\x94' ;;
            cross)  printf '\xe2\x9c\x96' ;;
            arrow)  printf '\xe2\x96\xb6' ;;
            info)   printf '\xe2\x84\xb9' ;;
            warn)   printf '\xe2\x9a\xa0' ;;
            bullet) printf '\xe2\x80\xa2' ;;
            hline)  printf '\xe2\x94\x80' ;;
            dot)    printf '\xc2\xb7' ;;
            tl) printf '\xe2\x95\xad' ;;
            tr) printf '\xe2\x95\xae' ;;
            bl) printf '\xe2\x95\xb0' ;;
            br) printf '\xe2\x95\xaf' ;;
            v)  printf '\xe2\x94\x82' ;;
        esac
    else
        case "$1" in
            check)  printf '[OK]' ;;
            cross)  printf '[X]' ;;
            arrow)  printf '>' ;;
            info)   printf 'i' ;;
            warn)   printf '!' ;;
            bullet) printf '*' ;;
            hline)  printf '-' ;;
            dot)    printf '.' ;;
            tl|tr|bl|br) printf '+' ;;
            v) printf '|' ;;
        esac
    fi
}

ui_width() {
    local w
    w=$(tput cols 2>/dev/null || echo 80)
    (( w > 0 )) || w=80
    printf '%d' "$w"
}

ui_hr() {
    (( QUIET_LEVEL >= 2 )) && return
    local w ch line
    w=$(ui_width); (( w > 80 )) && w=80
    ch=$(ui_glyph hline)
    printf -v line '%*s' "$w" ''
    printf '%s%s%s\n' "$C_GRAY" "${line// /$ch}" "$C_RESET"
}

ui_title()  { (( QUIET_LEVEL >= 2 )) && return; printf '\n%s%s %s%s\n' "$C_CYAN$C_BOLD" "$(ui_glyph arrow)" "$*" "$C_RESET"; ui_hr; }
ui_info()   { (( QUIET_LEVEL >= 2 )) && return; printf '  %s%s%s %s\n' "$C_BLUE"   "$(ui_glyph info)"  "$C_RESET" "$*"; }
ui_ok()     { (( QUIET_LEVEL >= 2 )) && return; printf '  %s%s%s %s\n' "$C_GREEN"  "$(ui_glyph check)" "$C_RESET" "$*"; }
ui_warn()   { printf '  %s%s%s %s\n' "$C_YELLOW" "$(ui_glyph warn)"  "$C_RESET" "$*"; }
ui_err()    { printf '  %s%s%s %s\n' "$C_RED$C_BOLD" "$(ui_glyph cross)" "$C_RESET" "$*" >&2; }
ui_muted()  { (( QUIET_LEVEL >= 1 )) && return; printf '  %s%s%s\n' "$C_DIM$C_GRAY" "$*" "$C_RESET"; }
ui_step()   { (( QUIET_LEVEL >= 2 )) && return; printf '\n%s[%d/%d]%s %s %s%s%s\n' "$C_MAGENTA" "$1" "$2" "$C_RESET" "$(ui_glyph arrow)" "$C_BOLD" "$3" "$C_RESET"; }
ui_sub()    { (( QUIET_LEVEL >= 1 )) && return; printf '    %s%s%s %s\n' "$C_GRAY" "$(ui_glyph dot)" "$C_RESET" "$*"; }

# Collapsed summary line for a finished step.
ui_done() {
    local label="$1" stat="${2:-}"
    (( QUIET_LEVEL >= 2 )) && return
    if [[ -n $stat ]]; then
        printf '    %s%s%s %s %s\xe2\x80\x94%s %s%s%s\n' \
            "$C_GREEN" "$(ui_glyph check)" "$C_RESET" "$label" \
            "$C_DIM$C_GRAY" "$C_RESET" "$C_GRAY" "$stat" "$C_RESET"
    else
        printf '    %s%s%s %s\n' "$C_GREEN" "$(ui_glyph check)" "$C_RESET" "$label"
    fi
}

ui_fail() {
    local label="$1" rc="${2:-1}"
    printf '    %s%s%s %s %s(rc=%s)%s\n' \
        "$C_RED$C_BOLD" "$(ui_glyph cross)" "$C_RESET" "$label" "$C_DIM$C_GRAY" "$rc" "$C_RESET" >&2
}

# Live log monitor: follow $file, print spinner frame plus last tail line.
# Replaces the old blind spinner.
_MON_PID=0
ui_monitor_start() {
    (( QUIET_LEVEL >= 2 )) && return
    (( ${UI_VERBOSE:-0} )) && { ui_sub "$1"; return; }
    (( UI_TTY )) || { ui_sub "$1"; return; }
    local label="$1" file="$2" hint="${3:-}"
    (
        local frames
        if (( UI_UNICODE )); then
            frames=($'\xe2\xa0\x8b' $'\xe2\xa0\x99' $'\xe2\xa0\xb9' $'\xe2\xa0\xb8' $'\xe2\xa0\xbc' $'\xe2\xa0\xb4' $'\xe2\xa0\xa6' $'\xe2\xa0\xa7' $'\xe2\xa0\x87' $'\xe2\xa0\x8f')
        else
            frames=('|' '/' '-' '\\')
        fi
        local i=0
        trap 'exit 0' TERM
        while :; do
            local last="" w max
            w=$(tput cols 2>/dev/null || echo 80)
            max=$(( w - 10 - ${#label} - ${#hint} ))
            (( max < 10 )) && max=10
            if [[ -f $file ]]; then
                last=$(tail -n 1 "$file" 2>/dev/null | tr -d '\r' | sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g')
                last=${last:0:max}
            fi
            printf "\r\033[K    %s%s%s %s%s  %s%s%s" \
                "$C_CYAN" "${frames[i]}" "$C_RESET" \
                "$label" \
                "$( [[ -n $hint ]] && printf ' %s(%s)%s' "$C_DIM$C_GRAY" "$hint" "$C_RESET" )" \
                "$C_DIM$C_GRAY" "$last" "$C_RESET"
            i=$(( (i+1) % ${#frames[@]} ))
            sleep 0.12
        done
    ) &
    _MON_PID=$!
    disown "$_MON_PID" 2>/dev/null || true
}

ui_monitor_stop() {
    if (( _MON_PID > 0 )) 2>/dev/null; then
        kill "$_MON_PID" 2>/dev/null || true
        wait "$_MON_PID" 2>/dev/null || true
        _MON_PID=0
        (( UI_TTY )) && printf '\r\033[K'
    fi
}

# Back-compat aliases used elsewhere.
ui_spinner_start() { ui_monitor_start "$1" /dev/null; }
ui_spinner_stop()  { ui_monitor_stop; }

ui_print_logo() {
    local logo="$1"
    [[ -f $logo ]] || return 0
    (( QUIET_LEVEL >= 1 )) && return
    local w; w=$(ui_width)
    (( w < 60 )) && return 0
    printf '%s' "$C_GREEN$C_BOLD"
    cat "$logo"
    printf '%s\n' "$C_RESET"
}

# Pretty banner box used for the final summary.
ui_box() {
    local title="$1"; shift
    local lines=("$@")
    local tl tr bl br v h
    tl=$(ui_glyph tl); tr=$(ui_glyph tr); bl=$(ui_glyph bl); br=$(ui_glyph br)
    v=$(ui_glyph v);   h=$(ui_glyph hline)
    local maxlen=${#title}
    local l
    for l in "${lines[@]}"; do
        local stripped; stripped=$(printf '%s' "$l" | sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g')
        (( ${#stripped} > maxlen )) && maxlen=${#stripped}
    done
    (( maxlen < 30 )) && maxlen=30
    local bar; printf -v bar '%*s' "$((maxlen+2))" ''; bar=${bar// /$h}
    printf '\n  %s%s%s%s%s\n' "$C_CYAN" "$tl" "$bar" "$tr" "$C_RESET"
    printf '  %s%s%s %s%-*s%s %s%s%s\n' "$C_CYAN" "$v" "$C_RESET" "$C_BOLD" "$maxlen" "$title" "$C_RESET" "$C_CYAN" "$v" "$C_RESET"
    printf '  %s%s%s%s%s\n' "$C_CYAN" "$v" "$bar" "$v" "$C_RESET"
    for l in "${lines[@]}"; do
        local stripped; stripped=$(printf '%s' "$l" | sed -E 's/\x1b\[[0-9;]*[a-zA-Z]//g')
        local pad=$(( maxlen - ${#stripped} ))
        printf '  %s%s%s %s%*s %s%s%s\n' "$C_CYAN" "$v" "$C_RESET" "$l" "$pad" "" "$C_CYAN" "$v" "$C_RESET"
    done
    printf '  %s%s%s%s%s\n' "$C_CYAN" "$bl" "$bar" "$br" "$C_RESET"
}
