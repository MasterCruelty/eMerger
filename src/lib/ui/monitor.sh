#!/usr/bin/env bash
# Live log monitor shown while a command runs.

: "${EMERGER_SPINNER:=}"            # braille, dots, pulse or line

# Print microsecond count $1 as 4.2s, 42s or 1m03s.
_ui_format_us() {
    local us="$1" seconds
    seconds=$(( us / 1000000 ))
    if (( seconds < 10 )); then
        printf '%d.%ds' "$seconds" $(( (us / 100000) % 10 ))
    elif (( seconds < 60 )); then
        printf '%ds' "$seconds"
    else
        printf '%dm%02ds' $(( seconds / 60 )) $(( seconds % 60 ))
    fi
}

# Print the wall clock in microseconds (whole seconds padded with zeros
# when EPOCHREALTIME is missing).
_ui_now_us() {
    if [[ -n ${EPOCHREALTIME:-} ]]; then
        printf '%s' "${EPOCHREALTIME/[.,]/}"
    else
        printf '%s000000' "$(date +%s)"
    fi
}

# Set _UI_FRAMES to the EMERGER_SPINNER style: braille by default and for an
# unknown name, pulse in ASCII mode unless the style is line.
_ui_spinner_frames() {
    local style="${EMERGER_SPINNER:-}"
    if [[ -z $style ]]; then
        if (( UI_HAS_UNICODE )); then style=braille; else style=pulse; fi
    fi
    (( UI_HAS_UNICODE )) || [[ $style == line ]] || style=pulse
    case "$style" in
        dots)    _UI_FRAMES=(⠁ ⠈ ⠐ ⠠ ⢀ ⡀ ⠄ ⠂) ;;
        line)    _UI_FRAMES=('|' '/' '-' '\') ;;
        pulse)   _UI_FRAMES=('.  ' '.. ' '.:.' ':::' ' ::' '  :' '   ' '  .' ' ..' '.:.' ':::' ':: ' ':  ' '   ') ;;
        *)       _UI_FRAMES=(⠉ ⠘ ⠰ ⢠ ⣀ ⡄ ⠆ ⠃) ;;
    esac
}

# Set _UI_WAVE to ".:::." bouncing across 8 columns, for steps with no
# known progress.
_ui_wave_frames() {
    local track=8 shape='.:::.' position line frames=() j column k
    for (( position=-${#shape}+1; position<track; position++ )); do
        printf -v line '%*s' "$track" ''
        for (( j=0; j<${#shape}; j++ )); do
            column=$(( position + j ))
            (( column >= 0 && column < track )) && line="${line:0:column}${shape:j:1}${line:column+1}"
        done
        frames+=("$line")
    done
    for (( k=${#frames[@]}-2; k>0; k-- )); do frames+=("${frames[k]}"); done
    _UI_WAVE=("${frames[@]}")
}

# PID of the running monitor subshell, 0 when none runs.
_MONITOR_PID=0
# Microsecond clock at the last ui_monitor_start, 0 once ui_monitor_stop read it.
_MONITOR_START_US=0

# Show step label $1 live while a command writes log file $2, with hint $3:
# spinner, progress bar (or wave), elapsed time and last output line. Under
# -qq nothing is shown, under -v or off a terminal one plain line. Reads the
# log through an fd, no forks per frame except a parent check every 16
# frames. A line without a newline (a prompt waiting for input) is shown once
# no output came for 2 s (20 frames).
ui_monitor_start() {
    _MONITOR_START_US=$(_ui_now_us)
    (( QUIET_LEVEL >= 2 )) && return
    (( ${UI_VERBOSE:-0} )) && { ui_sub "$1"; return; }
    (( UI_IS_TTY )) || { ui_sub "$1"; return; }
    local label="$1" file="$2" hint="${3:-}"
    _ui_spinner_frames
    _ui_wave_frames
    ui_cursor_hide
    (
        local frames=("${_UI_FRAMES[@]}") wave=("${_UI_WAVE[@]}")
        local frame_count=${#frames[@]} wave_count=${#wave[@]} grad=("${UI_GRADIENT[@]}") gradient_count=${#UI_GRADIENT[@]}
        local tick=0 width=80 start=$SECONDS elapsed last="" line carry="" max spinner_color read_fd="" n
        local manager="${_PKG_CURRENT:-}" anim progress_text shown idle=0 parent=$$
        local hint_colored="" clock ellipsis='...'
        (( UI_HAS_UNICODE )) && ellipsis='…'

        progress_reset
        [[ -n $hint ]] && hint_colored=" $C_DIM$C_GRAY($hint)$C_RESET"
        trap 'exit 0' TERM
        while :; do
            if (( tick % 16 == 0 )); then
                sys_is_parent_alive "$parent" || exit 0
                # Ask /dev/tty: here stdout is the substitution's pipe and a
                # background job's stdin is /dev/null, so tput would say 80.
                width=$(tput cols 2>/dev/null </dev/tty || echo 80); (( width > 0 )) || width=80
            fi
            elapsed=$(( SECONDS - start ))
            _ui_monitor_read
            _ui_monitor_frame
            tick=$(( tick + 1 ))
            sleep 0.1
        done
    ) 9>&- &
    # Not disowned: ui_monitor_stop waits for it, so no frame lands after the
    # line is cleared.
    _MONITOR_PID=$!
}

# Record the elapsed time of the last ui_monitor_start in UI_LAST_ELAPSED,
# stop the monitor, wait for it, clear its line and show the cursor.
ui_monitor_stop() {
    if (( _MONITOR_START_US > 0 )); then
        # Read by ui_done.
        # shellcheck disable=SC2034
        UI_LAST_ELAPSED=$(_ui_format_us $(( $(_ui_now_us) - _MONITOR_START_US )))
        _MONITOR_START_US=0
    fi
    if (( _MONITOR_PID > 0 )) 2>/dev/null; then
        kill "$_MONITOR_PID" 2>/dev/null || true
        wait "$_MONITOR_PID" 2>/dev/null || true
        _MONITOR_PID=0
        (( UI_IS_TTY )) && printf '\r\e[K'
        ui_cursor_show
    fi
    return 0
}

# Monitor helpers, run inside ui_monitor_start's subshell on its locals.

# Open the log once it exists, then read at most 400 new lines into last
# (the newest line, or its progress message), feeding each to progress_feed.
# Keep a partial line in carry and show it after 20 idle frames.
_ui_monitor_read() {
    if [[ -z $read_fd && -f $file && $file != /dev/null ]]; then
        exec {read_fd}<"$file" || read_fd=""
    fi
    if [[ -n $read_fd ]]; then
        # At most 400 lines per frame, so a burst cannot freeze the spinner.
        idle=$(( idle + 1 ))
        for (( n=0; n<400; n++ )); do
            if IFS= read -r -u "$read_fd" line; then
                line="$carry$line"; carry=""; idle=0
            else
                [[ -n $line ]] && idle=0
                carry+="$line"   # partial line, finish it next frame
                break
            fi
            _ui_clean_line "$line"; line=$_UI_CLEANED
            [[ -z $line ]] && continue
            PROGRESS_MESSAGE=""
            progress_feed "$manager" "$line"
            last=${PROGRESS_MESSAGE:-$line}
        done
        if (( idle == 20 )) && [[ -n $carry ]]; then
            _ui_clean_line "$carry"
            [[ -n $_UI_CLEANED ]] && last=$_UI_CLEANED
        fi
        last=${last//$'\t'/ }
        last=${last#"${last%%[![:space:]]*}"}
    fi
}

# Draw one frame on the current line: spinner, label, hint, progress bar or
# wave, elapsed time and as much of last as fits the width, cut with an
# ellipsis, one column to spare so the line never wraps.
_ui_monitor_frame() {
    progress_text=""
    if (( PROGRESS_TOTAL > 0 )); then
        ui_bar $(( PROGRESS_CURRENT * 100 / PROGRESS_TOTAL )); anim=$_UI_BAR
        progress_text="${PROGRESS_CURRENT}/${PROGRESS_TOTAL}"
    elif (( PROGRESS_PERCENT >= 0 )); then
        ui_bar "$PROGRESS_PERCENT"; anim=$_UI_BAR
        progress_text="${PROGRESS_PERCENT}%"
    else
        anim="${C_CYAN}${wave[tick % wave_count]}  ${C_RESET}"
        (( PROGRESS_CURRENT > 0 )) && progress_text="#${PROGRESS_CURRENT}"
    fi
    printf -v clock '%d:%02d' $(( elapsed / 60 )) $(( elapsed % 60 ))

    # Indent 4, spinner, space, label, " (hint)", 2, bar or wave 10, space,
    # counter (7 or more), 2, clock, 2, then the spare column.
    max=$(( width - 4 - ${#frames[0]} - 1 - ${#label} - 2 - 10 - 1 - 2 - ${#clock} - 2 - 1 ))
    [[ -n $hint ]] && max=$(( max - ${#hint} - 3 ))
    if (( ${#progress_text} > 7 )); then max=$(( max - ${#progress_text} )); else max=$(( max - 7 )); fi
    (( max < 0 )) && max=0
    if (( ${#last} <= max )); then
        shown=$last
    elif (( max > ${#ellipsis} )); then
        shown=${last:0:max-${#ellipsis}}$ellipsis
    else
        shown=${last:0:max}
    fi
    if (( gradient_count > 0 )); then
        spinner_color=$'\e[38;5;'"${grad[(tick / 2) % gradient_count]}"'m'
    else
        spinner_color=$C_CYAN
    fi
    printf '\r\e[K    %s%s%s %s%s%s%s  %s %s%-7s%s  %s%s%s  %s%s%s' \
        "$spinner_color$C_BOLD" "${frames[tick % frame_count]}" "$C_RESET" \
        "$C_BOLD" "$label" "$C_RESET" \
        "$hint_colored" \
        "$anim" "$C_BOLD" "$progress_text" "$C_RESET" \
        "$C_GRAY" "$clock" "$C_RESET" \
        "$C_DIM$C_GRAY" "$shown" "$C_RESET"
}
