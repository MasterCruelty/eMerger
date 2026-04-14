#!/usr/bin/env bash
# Interactive TUI using gum or whiptail, falling back to a simple read loop.

tui_menu() {
    local choice
    if sys_has gum; then
        choice=$(gum choose --header="eMerger" \
            "Update all" \
            "Dry run" \
            "Security updates only" \
            "Include dev tools (rust/npm/pip...)" \
            "Show errors" \
            "Show history" \
            "Self-update" \
            "Quit") || return 0
    elif sys_has whiptail; then
        choice=$(whiptail --title "eMerger" --menu "Choose an action" 18 60 8 \
            "Update all"                    "full system update" \
            "Dry run"                       "simulate without changes" \
            "Security updates only"         "apt/dnf/zypper security" \
            "Include dev tools (rust/npm/pip...)" "also update toolchains" \
            "Show errors"                   "read log errors" \
            "Show history"                  "last 10 runs" \
            "Self-update"                   "git pull eMerger" \
            "Quit"                          "exit" \
            3>&1 1>&2 2>&3) || return 0
    else
        printf '\n  Install "gum" or "whiptail" for a nicer menu.\n\n'
        printf '    1) Update all\n    2) Dry run\n    3) Security only\n    4) + dev tools\n    5) Errors\n    6) History\n    7) Self-update\n    q) Quit\n\n'
        local pick
        read -r -p "  > " pick
        case "$pick" in
            1) choice="Update all" ;;
            2) choice="Dry run" ;;
            3) choice="Security updates only" ;;
            4) choice="Include dev tools (rust/npm/pip...)" ;;
            5) choice="Show errors" ;;
            6) choice="Show history" ;;
            7) choice="Self-update" ;;
            *) return 0 ;;
        esac
    fi

    case "$choice" in
        "Update all")                           ARG_YES=1 ;;
        "Dry run")                              ARG_DRY=1; DRY_RUN=1 ;;
        "Security updates only")                ARG_SECURITY=1; ARG_YES=1 ;;
        "Include dev tools"*)                   ARG_DEV=1; ARG_YES=1 ;;
        "Show errors")                          show_errors; exit 0 ;;
        "Show history")                         show_history; exit 0 ;;
        "Self-update")                          self_update "$EMERGER_ROOT"; exit $? ;;
        *) exit 0 ;;
    esac
}
