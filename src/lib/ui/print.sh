#!/usr/bin/env bash
# Message printers: section headers, status lines, results, logo, header
# line and box.

: "${QUIET_LEVEL:=0}"

# Print a dim horizontal rule across the header width. Hidden from -qq.
ui_rule() {
    (( QUIET_LEVEL >= 2 )) && return
    local width; width=$(_ui_columns)
    _ui_repeat "$(ui_glyph hline)" $(( width - 2 ))
    printf '  %s%s%s\n' "$C_DIM$C_GRAY" "$_UI_REPEATED" "$C_RESET"
}

# Step counter, shown by the next section header.
_UI_STEP_INDEX=0; _UI_STEP_TOTAL=0
# Set the step counter, $1 of $2, which the next ui_section shows and clears.
ui_step() {
    _UI_STEP_INDEX=$1; _UI_STEP_TOTAL=$2
    return 0
}

# Print section header for name $2 with icon $1 (arrow when empty) and dim
# note $3, ruled to the header width, with the ui_step counter when set:
#   ◆ apt  ~42s ──────────────────── ▰▰▱ 1/3
# Hidden from -qq. The bar is drawn for 12 steps or fewer.
ui_section() {
    (( QUIET_LEVEL >= 2 )) && return
    local icon="${1:-}" name="$2" note="${3:-}"
    [[ -z $icon ]] && icon=$(ui_glyph arrow)
    local width left right="" right_c="" fill
    width=$(_ui_columns)

    left="  $icon $name"
    [[ -n $note ]] && left+="  $note"

    if (( _UI_STEP_TOTAL > 0 )); then
        local bar="" step
        if (( _UI_STEP_TOTAL <= 12 )); then
            for (( step=1; step<=_UI_STEP_TOTAL; step++ )); do
                if (( step <= _UI_STEP_INDEX )); then bar+=$(ui_glyph pfull); else bar+=$(ui_glyph pempty); fi
            done
            bar+=" "
        fi
        right=" ${bar}${_UI_STEP_INDEX}/${_UI_STEP_TOTAL}"
        right_c=" ${C_MAGENTA}${bar}${C_BOLD}${_UI_STEP_INDEX}/${_UI_STEP_TOTAL}${C_RESET}"
        _UI_STEP_INDEX=0; _UI_STEP_TOTAL=0
    fi

    _ui_visible_width "$left";  local left_width=$_UI_WIDTH
    _ui_visible_width "$right"; local right_width=$_UI_WIDTH
    fill=$(( width - left_width - right_width - 2 ))
    (( fill < 3 )) && fill=3
    _ui_repeat "$(ui_glyph hline)" "$fill"

    printf '\n  %s%s%s %s%s%s' "$C_CYAN$C_BOLD" "$icon" "$C_RESET" "$C_BOLD" "$name" "$C_RESET"
    [[ -n $note ]] && printf '  %s%s%s' "$C_DIM$C_GRAY" "$note" "$C_RESET"
    printf ' %s%s%s%s\n' "$C_DIM$C_GRAY" "$_UI_REPEATED" "$C_RESET" "$right_c"
}

# Print a section header with the arrow glyph and title $*.
ui_title()  { ui_section "" "$*"; }
# Print message $* on one indented status line with its glyph: info and ok
# hidden from -qq, muted and sub from -q, warn and err always shown, on stderr.
ui_info()   { (( QUIET_LEVEL >= 2 )) && return; printf '    %s%s%s %s\n' "$C_BLUE"   "$(ui_glyph info)"  "$C_RESET" "$*"; }
ui_ok()     { (( QUIET_LEVEL >= 2 )) && return; printf '    %s%s%s %s\n' "$C_GREEN"  "$(ui_glyph check)" "$C_RESET" "$*"; }
ui_warn()   { printf '    %s%s%s %s\n' "$C_YELLOW" "$(ui_glyph warn)"  "$C_RESET" "$*" >&2; }
ui_err()    { printf '    %s%s%s %s\n' "$C_RED$C_BOLD" "$(ui_glyph cross)" "$C_RESET" "$*" >&2; }
ui_muted()  { (( QUIET_LEVEL >= 1 )) && return; printf '    %s%s%s\n' "$C_DIM$C_GRAY" "$*" "$C_RESET"; }
ui_sub()    { (( QUIET_LEVEL >= 1 )) && return; printf '    %s%s%s %s\n' "$C_GRAY" "$(ui_glyph dot)" "$C_RESET" "$*"; }

# Set by ui_monitor_stop, printed by the next ui_done/ui_fail.
UI_LAST_ELAPSED=""

# Set _UI_REPEATED to the dot leader that pads label $1 to column 26, at
# least two dots, so the results line up.
_ui_leader() {
    local label="$1" column=26 count
    _ui_visible_width "$label"
    count=$(( column - _UI_WIDTH ))
    (( count < 2 )) && count=2
    _ui_repeat "$(ui_glyph dot)" "$count"
}

# Print the success line of step $1 with dot leader, the elapsed time from
# ui_monitor_stop and optional stat $2. Hidden from -qq.
ui_done() {
    local label="$1" status="${2:-}" elapsed="$UI_LAST_ELAPSED"
    UI_LAST_ELAPSED=""
    (( QUIET_LEVEL >= 2 )) && return
    _ui_leader "$label"
    printf '    %s%s%s %s %s%s%s' "$C_GREEN" "$(ui_glyph check)" "$C_RESET" "$label" "$C_DIM$C_GRAY" "$_UI_REPEATED" "$C_RESET"
    [[ -n $elapsed ]]    && printf ' %s%6s%s' "$C_GRAY" "$elapsed" "$C_RESET"
    [[ -n $status ]] && printf '  %s%s%s' "$C_CYAN" "$status" "$C_RESET"
    printf '\n'
}

# Print the failure line of step $1 with the elapsed time and exit code $2
# (default 1) on stderr.
ui_fail() {
    local label="$1" rc="${2:-1}" elapsed="$UI_LAST_ELAPSED"
    UI_LAST_ELAPSED=""
    _ui_leader "$label"
    {
        printf '    %s%s%s %s%s%s %s%s%s' "$C_RED$C_BOLD" "$(ui_glyph cross)" "$C_RESET" "$C_RED" "$label" "$C_RESET" "$C_DIM$C_GRAY" "$_UI_REPEATED" "$C_RESET"
        [[ -n $elapsed ]] && printf ' %s%6s%s' "$C_GRAY" "$elapsed" "$C_RESET"
        printf '  %sexit %s%s\n' "$C_RED" "$rc" "$C_RESET"
    } >&2
}

# Print logo file $1 line by line in the gradient colours. Skipped when the
# file is missing, under -q, or on a terminal narrower than 64 columns.
ui_print_logo() {
    local logo="$1"
    [[ -f $logo ]] || return 0
    (( QUIET_LEVEL >= 1 )) && return
    local width; width=$(ui_width)
    (( width < 64 )) && return 0
    local line i=0 gradient_count=${#UI_GRADIENT[@]}
    printf '\n'
    while IFS= read -r line || [[ -n $line ]]; do
        if (( gradient_count > 0 )); then
            printf '  \e[38;5;%sm%s%s%s\n' "${UI_GRADIENT[i % gradient_count]}" "$C_BOLD" "$line" "$C_RESET"
        else
            printf '  %s%s%s\n' "$C_GREEN$C_BOLD" "$line" "$C_RESET"
        fi
        i=$(( i + 1 ))
    done <"$logo"
    printf '\n'
    return 0
}

# Print the system info line under the logo: items $@ separated by dots,
# empty ones skipped. Hidden from -q.
ui_header() {
    (( QUIET_LEVEL >= 1 )) && return
    local sep out="" item
    sep=" ${C_DIM}${C_GRAY}$(ui_glyph dot)${C_RESET} "
    for item in "$@"; do
        [[ -z $item ]] && continue
        [[ -n $out ]] && out+="$sep"
        out+="$item"
    done
    printf '  %s%s%s %s\n' "$C_CYAN" "$(ui_glyph diamond)" "$C_RESET" "$out"
}

# Print a box with title $1 in its top border around lines $2..., at least
# 44 columns wide, border colour from UI_BOX_COLOR (cyan by default).
ui_box() {
    local title="$1"; shift
    local lines=("$@")
    local border_color="${UI_BOX_COLOR:-$C_CYAN}"
    local tl tr bl br v h line
    tl=$(ui_glyph tl); tr=$(ui_glyph tr); bl=$(ui_glyph bl); br=$(ui_glyph br)
    v=$(ui_glyph v);   h=$(ui_glyph hline)
    local inner=$(( ${#title} + 4 ))
    for line in "${lines[@]}"; do
        _ui_visible_width "$line"
        (( _UI_WIDTH + 2 > inner )) && inner=$(( _UI_WIDTH + 2 ))
    done
    (( inner < 44 )) && inner=44
    _ui_repeat "$h" $(( inner - ${#title} - 3 ))
    printf '\n  %s%s%s %s%s%s %s%s%s%s\n' "$border_color" "$tl" "$h" "$C_RESET$C_BOLD" "$title" "$C_RESET" "$border_color" "$_UI_REPEATED" "$tr" "$C_RESET"
    for line in "${lines[@]}"; do
        _ui_visible_width "$line"
        local pad=$(( inner - 2 - _UI_WIDTH ))
        printf '  %s%s%s %s%*s %s%s%s\n' "$border_color" "$v" "$C_RESET" "$line" "$pad" "" "$border_color" "$v" "$C_RESET"
    done
    _ui_repeat "$h" "$inner"
    printf '  %s%s%s%s%s\n' "$border_color" "$bl" "$_UI_REPEATED" "$br" "$C_RESET"
}
