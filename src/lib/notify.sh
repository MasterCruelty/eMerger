#!/usr/bin/env bash
# Optional desktop notification at end of run.

notify_send_result() {
    sys_has notify-send || return 0
    [[ -n ${DISPLAY:-} || -n ${WAYLAND_DISPLAY:-} ]] || return 0
    local msg urgency=normal icon=emblem-default
    if (( SUMMARY_ERRORS > 0 )); then
        urgency=critical; icon=dialog-error
        msg="Finished with $SUMMARY_ERRORS error(s)."
    else
        msg="${#SUMMARY_MANAGERS[@]} manager(s) updated."
    fi
    notify-send -a eMerger -u "$urgency" -i "$icon" "eMerger" "$msg" 2>/dev/null || true
}
