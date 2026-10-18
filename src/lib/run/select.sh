#!/usr/bin/env bash
# Manager selection: which detected managers this run updates.

# Set RUN_SKIP_REASON to why detected manager $1 stays out of this run: dev,
# firmware, resume, only, except, security or download. Empty means it runs.
run_skip_reason() {
    local manager="$1"
    RUN_SKIP_REASON=""
    if pkg_is_dev "$manager" && (( ! ${ARG_DEV:-0} )); then
        RUN_SKIP_REASON=dev
    elif [[ $manager == fwupd ]] && { (( ${ARG_NO_FIRMWARE:-0} )) || (( ! ${ARG_FIRMWARE:-0} )); }; then
        RUN_SKIP_REASON=firmware
    # Pi bootloader: always checked, flashed only with --firmware.
    elif [[ $manager == rpi-eeprom ]] && (( ${ARG_NO_FIRMWARE:-0} )); then
        RUN_SKIP_REASON=firmware
    elif (( ${ARG_RESUME:-0} )) && resume_has "$manager"; then
        RUN_SKIP_REASON=resume
    elif [[ -n ${ARG_ONLY:-} ]] && ! args_list_has "$ARG_ONLY" "$manager"; then
        RUN_SKIP_REASON=only
    elif [[ -n ${ARG_EXCEPT:-} ]] && args_list_has "$ARG_EXCEPT" "$manager"; then
        RUN_SKIP_REASON=except
    elif (( ${ARG_SECURITY:-0} )) && ! pkg_has_security "$manager"; then
        RUN_SKIP_REASON=security
    elif (( ${ARG_DOWNLOAD_ONLY:-0} )) && ! pkg_has_download_only "$manager"; then
        RUN_SKIP_REASON=download
    fi
    return 0
}

# Return 0 if a manager selected for this run, or --deep-clean, needs sudo.
# Same selection as the run loop (run_skip_reason).
run_needs_sudo() {
    local manager
    for manager in "${PKG_MANAGERS[@]}"; do
        pkg_detect "$manager" || continue
        run_skip_reason "$manager"
        [[ -n $RUN_SKIP_REASON ]] && continue
        if pkg_needs_sudo "$manager"; then return 0; fi
    done
    (( ${ARG_DEEP_CLEAN:-0} ))
}

# Append each detected manager this run updates to the caller's arrays:
# `detected`, and `parallel` (under --parallel, when it can run beside others)
# or `serial`. A skipped manager is reported unless it is skipped silently.
run_select() {
    local manager
    for manager in "${PKG_MANAGERS[@]}"; do
        pkg_detect "$manager" || continue
        run_skip_reason "$manager"
        case $RUN_SKIP_REASON in
            resume) ui_muted "skip $manager (resume)"; continue ;;
            except) ui_muted "skip $manager (--except)"; continue ;;
            security)
                ui_warn "skip $manager: no security-only updates, --security never runs a full upgrade"
                [[ $manager == apt ]] && ui_warn "install the unattended-upgrades package to get security-only updates with apt"
                log_warn "$manager skipped: no security channel"
                continue
                ;;
            download)
                ui_muted "skip $manager (no download-only mode)"
                log_warn "$manager skipped: no download-only mode"
                continue
                ;;
            ?*) continue ;;
        esac
        detected+=("$manager")
        if (( ARG_PARALLEL )) && pkg_is_parallelizable "$manager"; then
            parallel+=("$manager")
        else
            serial+=("$manager")
        fi
    done
}
