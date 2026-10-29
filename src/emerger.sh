#!/usr/bin/env bash
# eMerger - one-command system updater.
# Entry point: arg parsing + orchestration. Logic lives in src/lib/.

set -Eeuo pipefail
IFS=$'\n\t'

EMERGER_SRC=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
EMERGER_ROOT=$(dirname "$EMERGER_SRC")
EMERGER_LIB="$EMERGER_SRC/lib"
EMERGER_VERSION=$(cat "$EMERGER_ROOT/VERSION" 2>/dev/null || echo "0.0.0")

# The checkout's own code runs as this user, as root under sudo: refuse to start
# when another local user can rewrite it. Group write counts only outside the
# user's private group.
if [[ $(id -gn) == "$(id -un)" ]]; then
    _tree_bad=$(find "$EMERGER_SRC" ! -type l \( -perm /002 -o \( -perm /020 ! -gid "$(id -g)" \) \) -print -quit 2>/dev/null || true)
else
    _tree_bad=$(find "$EMERGER_SRC" ! -type l -perm /022 -print -quit 2>/dev/null || true)
fi
if [[ -n $_tree_bad ]]; then
    printf 'eMerger: %s is writable by group or other, not run. Fix: chmod -R go-w "%s"\n' "$_tree_bad" "$EMERGER_SRC" >&2
    exit 1
fi
unset _tree_bad

: "${XDG_CACHE_HOME:=$HOME/.cache}"
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"
EMERGER_CACHE="$XDG_CACHE_HOME/emerger"
EMERGER_CONFIG="$XDG_CONFIG_HOME/emerger"
EMERGER_STATE="$XDG_STATE_HOME/emerger"

# shellcheck source=lib/load.sh
source "$EMERGER_LIB/load.sh" all

trust_home || exit 1
mkdir -p "$EMERGER_CACHE" "$EMERGER_STATE"
# Log and history hold manager output: no other user reads them.
chmod 700 "$EMERGER_CACHE" "$EMERGER_STATE"

# 1) User global config
if [[ -f "$EMERGER_CONFIG/config.sh" ]]; then
    trust_file "$EMERGER_CONFIG/config.sh" || exit 1
    # shellcheck disable=SC1091
    # `|| true`: a final `[[ test ]] && VAR=1` returns 1 and a failing line
    # must not end the run silently under errexit.
    source "$EMERGER_CONFIG/config.sh" || true
fi

# 2) Profile (if --profile seen in argv) - loaded BEFORE explicit flags so
#    CLI overrides stay authoritative.
args_prescan_profile "$@"
[[ -n ${PROFILE_PRELOAD:-} ]] && profile_load "$PROFILE_PRELOAD"

# 3) Explicit CLI flags
args_parse "$@"

knobs_validate
# Config and profile may set NO_COLOR, EMERGER_EMOJI or ARG_ASCII.
ui_reinit

quiet_hours_check

SUDO_KEEPALIVE_PID=0
# Stop the monitor and the sudo keep-alive, remove the capture and
# --parallel timing files, show the cursor and release the lock. EXIT trap.
_cleanup() {
    ui_monitor_stop
    run_cmd_cleanup
    rm -f "$EMERGER_STATE"/parallel-*.secs 2>/dev/null || true
    ui_cursor_show
    if (( SUDO_KEEPALIVE_PID > 0 )); then
        kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    fi
    lock_release
}

# Stop the run on signal $1 (INT or TERM): end the parallel managers, then
# exit 1 so the EXIT trap removes temp files and releases the lock last.
_interrupted() {
    trap '' INT TERM
    local pid
    # Manager first, so its subshell reaches its trap and cleans up.
    for pid in "${_PARALLEL_PIDS[@]}"; do
        pkill -TERM -P "$pid" 2>/dev/null || true
        kill "$pid" 2>/dev/null || true
    done
    ui_monitor_stop
    printf '\n' >&2
    ui_err "Interrupted (SIG$1), stopping."
    log_warn "interrupted by SIG$1"
    exit 1
}
trap _cleanup EXIT
trap '_interrupted INT' INT
trap '_interrupted TERM' TERM

log_init

# Subcommand-style short-circuits.
(( ARG_HELP ))    && { cat "$EMERGER_LIB/help.txt"; exit 0; }
(( ARG_VERSION )) && { printf 'eMerger %s\n' "$EMERGER_VERSION"; exit 0; }
(( ARG_ERRORS ))     && { log_show_errors; exit 0; }
(( ARG_HISTORY )) && { history_show; exit 0; }
(( ARG_CHANGED )) && { diff_show; exit 0; }
(( ARG_DOCTOR ))  && { doctor_run; exit $?; }
(( ARG_LIST_PROFILES )) && { profile_list; exit 0; }
[[ -n $ARG_CHANGELOG ]] && { changelog_show "$ARG_CHANGELOG"; exit $?; }
[[ -n $ARG_METRICS ]] && { metrics_export "$ARG_METRICS"; exit $?; }

# Global lock, before anything that changes the system or eMerger's state.
if ! lock_acquire; then exit 1; fi

(( ARG_SELF_UPDATE ))      && { self_update "$EMERGER_ROOT"; exit $?; }
(( ARG_AUTO_UPDATE ))      && { autoupdate_install "$EMERGER_ROOT"; exit $?; }
if (( ARG_REBUILD_CACHE )); then
    if (( DRY_RUN )); then
        ui_sub "[dry-run] rm -rf $EMERGER_CACHE"
    else
        rm -rf "$EMERGER_CACHE"; mkdir -p "$EMERGER_CACHE"; chmod 700 "$EMERGER_CACHE"; ui_ok "Detection cache cleared"
    fi
fi
(( ARG_ROLLBACK )) && { snapshot_rollback; exit $?; }
if (( ARG_REBOOT )); then
    reboot_check
    if (( REBOOT_IS_NEEDED )); then
        reboot_now; exit 0
    else
        ui_ok "No reboot needed."; exit 0
    fi
fi

ignore_load
plugins_load
resume_load
# Each run starts a fresh resume cursor: only --resume reads the last one.
(( ARG_RESUME )) || resume_clear

# Print the logo, the system line and the weather, as flags and quiet level
# allow. --json turns all of them off.
_main_header() {
    if (( ARG_JSON )); then
        ARG_NO_LOGO=1; ARG_NO_INFO=1; QUIET_LEVEL=3
    fi

    if (( ! ARG_NO_LOGO )); then
        ui_print_logo "$EMERGER_SRC/logo/logo.txt"
    fi

    if (( QUIET_LEVEL < 2 )); then
        if (( ! ARG_NO_INFO )); then
            ui_header "${C_BOLD}$(sys_read_distro)${C_RESET}" "$(uname -m)" "$(date '+%Y-%m-%d %H:%M')" \
                "${C_CYAN}eMerger v$EMERGER_VERSION${C_RESET}"
        else
            ui_header "${C_CYAN}eMerger v$EMERGER_VERSION${C_RESET}"
        fi
    fi

    if (( ARG_WEATHER )) && sys_has curl; then
        local weather
        weather=$(curl -sS --max-time 3 'https://wttr.in/?format=%l:+%c+%t+%w+%m' 2>/dev/null | head -c 512 | run_sanitize || true)
        weather=${weather//$'\n'/ }
        [[ -n $weather ]] && ui_muted "$weather"
    fi
    return 0
}

# Close the run started at SECONDS value $1: package diff, summary,
# notification, ibus restart, resume cleanup. Exit 3 when a manager failed,
# 4 under --reboot-exit with a reboot pending.
_main_finish() {
    local start="$1"
    if (( ! DRY_RUN )); then
        diff_snapshot "$DIFF_AFTER" 2>/dev/null || true
        diff_compute  "$DIFF_BEFORE" "$DIFF_AFTER" "$DIFF_LAST" 2>/dev/null || true
    fi

    summary_print $((SECONDS - start))
    notify_send_result

    # Restart ibus if running: updates to ibus/glib/gtk replace files on
    # disk while the daemon keeps the old versions mapped in memory, which
    # breaks input methods until the daemon is recycled. No-op if absent.
    if (( ! DRY_RUN )) && command -v ibus >/dev/null 2>&1 && pgrep -x ibus-daemon >/dev/null 2>&1; then
        # Keep the lock fd from the restarted daemon.
        ibus restart >/dev/null 2>&1 9>&- || true
    fi

    if (( SUMMARY_ERRORS == 0 )); then
        resume_clear
    fi

    if (( SUMMARY_ERRORS > 0 )); then
        exit 3
    fi
    if (( ARG_REBOOT_EXIT )) && (( ${REBOOT_IS_NEEDED:-0} == 1 )); then
        exit 4
    fi
}

# Run one update: header, pre-flight checks, sudo, snapshot, hooks, every
# selected manager, cleaning, then _main_finish, which sets the exit status.
main() {
    local start=$SECONDS

    _main_header

    ignore_advisory

    battery_precheck
    disk_precheck
    rpi_health_check

    # sudo keep-alive only if some manager needs it.
    local manager
    if run_needs_sudo && (( ! DRY_RUN )) && ! sys_is_root; then
        if ! sudo -v; then
            ui_err "sudo authentication failed"
            exit 1
        fi
        run_sudo_keepalive
    fi

    (( ARG_REFRESH_MIRRORS )) && mirrors_refresh
    # --snapshot asks for a safety net: no snapshot, no update.
    if (( ARG_SNAPSHOT )) && ! snapshot_create; then
        ui_err "No snapshot taken. Rerun without --snapshot to update anyway."
        exit 1
    fi

    # Snapshot installed packages for diff. A dry run keeps the last real diff.
    (( DRY_RUN )) || diff_snapshot "$DIFF_BEFORE" 2>/dev/null || true

    hooks_run pre

    # Filled by run_select in this scope.
    # shellcheck disable=SC2034
    local detected=() parallel=() serial=()
    run_select

    # Count the parallel group as one step.
    local total=${#serial[@]}
    (( ${#parallel[@]} > 0 )) && total=$(( total + 1 ))
    (( total == 0 )) && ui_warn "No supported package managers detected."

    local step=0 step_start
    for manager in "${serial[@]}"; do
        step=$((step+1))
        ui_step "$step" "$total" "$manager"
        step_start=$SECONDS
        if pkg_run "$manager"; then
            summary_add "$manager" ok $(( SECONDS - step_start ))
            resume_mark "$manager"
        else
            summary_add "$manager" fail $(( SECONDS - step_start ))
        fi
    done

    if (( ${#parallel[@]} > 0 )); then
        run_parallel "$((step+1))" "$total" "${parallel[@]}"
    fi

    if (( ! ARG_KEEP_CACHE )); then clean_cache; clean_open_deleted; fi
    (( ARG_KEEP_TRASH )) || clean_trash
    if (( ARG_DEEP_CLEAN )); then clean_deep; clean_containers; fi

    hooks_run post

    _main_finish "$start"
}

main
