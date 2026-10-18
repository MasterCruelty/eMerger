#!/usr/bin/env bash
# Optional desktop notification at end of run.

# Show the run's outcome as a desktop notification: notify-send on a Linux
# graphical session, osascript on macOS. Silent when neither applies.
notify_send_result() {
    local message urgency=normal icon=emblem-default
    if (( SUMMARY_ERRORS > 0 )); then
        urgency=critical; icon=dialog-error
        message="Finished with $SUMMARY_ERRORS error(s)."
    else
        message="${#SUMMARY_MANAGERS[@]} manager(s) updated."
    fi
    if sys_has notify-send && [[ -n ${DISPLAY:-} || -n ${WAYLAND_DISPLAY:-} ]]; then
        notify-send -a eMerger -u "$urgency" -i "$icon" "eMerger" "$message" 2>/dev/null 9>&- || true
    elif sys_is_macos && sys_has osascript; then
        # msg is built above from counts only, never from outside text.
        osascript -e "display notification \"$message\" with title \"eMerger\"" >/dev/null 2>&1 9>&- || true
    fi
    return 0
}
