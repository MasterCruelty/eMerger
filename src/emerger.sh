#!/usr/bin/env bash
# eMerger - one-command system updater.
# Entry point: arg parsing + orchestration. Logic lives in src/lib/.

set -Eeuo pipefail
IFS=$'\n\t'

EMERGER_SRC=$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")
EMERGER_ROOT=$(dirname "$EMERGER_SRC")
EMERGER_LIB="$EMERGER_SRC/lib"
EMERGER_VERSION=$(cat "$EMERGER_ROOT/VERSION" 2>/dev/null || echo "0.0.0")

: "${XDG_CACHE_HOME:=$HOME/.cache}"
: "${XDG_CONFIG_HOME:=$HOME/.config}"
: "${XDG_STATE_HOME:=$HOME/.local/state}"
EMERGER_CACHE="$XDG_CACHE_HOME/emerger"
EMERGER_CONFIG="$XDG_CONFIG_HOME/emerger"
EMERGER_STATE="$XDG_STATE_HOME/emerger"
mkdir -p "$EMERGER_CACHE" "$EMERGER_STATE"

# shellcheck source=lib/ui.sh
source "$EMERGER_LIB/ui.sh"
# shellcheck source=lib/log.sh
source "$EMERGER_LIB/log.sh"
# shellcheck source=lib/sys.sh
source "$EMERGER_LIB/sys.sh"
# shellcheck source=lib/progress.sh
source "$EMERGER_LIB/progress.sh"
# shellcheck source=lib/estimate.sh
source "$EMERGER_LIB/estimate.sh"
# shellcheck source=lib/retry.sh
source "$EMERGER_LIB/retry.sh"
# shellcheck source=lib/run.sh
source "$EMERGER_LIB/run.sh"
# shellcheck source=lib/args.sh
source "$EMERGER_LIB/args.sh"
# shellcheck source=lib/ignore.sh
source "$EMERGER_LIB/ignore.sh"
# shellcheck source=lib/packages.sh
source "$EMERGER_LIB/packages.sh"
# shellcheck source=lib/clean.sh
source "$EMERGER_LIB/clean.sh"
# shellcheck source=lib/hooks.sh
source "$EMERGER_LIB/hooks.sh"
# shellcheck source=lib/update.sh
source "$EMERGER_LIB/update.sh"
# shellcheck source=lib/notify.sh
source "$EMERGER_LIB/notify.sh"
# shellcheck source=lib/reboot.sh
source "$EMERGER_LIB/reboot.sh"
# shellcheck source=lib/diff.sh
source "$EMERGER_LIB/diff.sh"
# shellcheck source=lib/disk.sh
source "$EMERGER_LIB/disk.sh"
# shellcheck source=lib/snapshot.sh
source "$EMERGER_LIB/snapshot.sh"
# shellcheck source=lib/mirrors.sh
source "$EMERGER_LIB/mirrors.sh"
# shellcheck source=lib/resume.sh
source "$EMERGER_LIB/resume.sh"
# shellcheck source=lib/lock.sh
source "$EMERGER_LIB/lock.sh"
# shellcheck source=lib/doctor.sh
source "$EMERGER_LIB/doctor.sh"
# shellcheck source=lib/changelog.sh
source "$EMERGER_LIB/changelog.sh"
# shellcheck source=lib/report.sh
source "$EMERGER_LIB/report.sh"
# shellcheck source=lib/wizard.sh
source "$EMERGER_LIB/wizard.sh"
# shellcheck source=lib/profiles.sh
source "$EMERGER_LIB/profiles.sh"
# shellcheck source=lib/summary.sh
source "$EMERGER_LIB/summary.sh"
# shellcheck source=lib/tui.sh
source "$EMERGER_LIB/tui.sh"
# shellcheck source=lib/plugins.sh
source "$EMERGER_LIB/plugins.sh"
# shellcheck source=lib/metrics.sh
source "$EMERGER_LIB/metrics.sh"

# 1) User global config
if [[ -f "$EMERGER_CONFIG/config.sh" ]]; then
    # shellcheck disable=SC1091
    source "$EMERGER_CONFIG/config.sh"
fi

# 2) Profile (if --profile seen in argv) - loaded BEFORE explicit flags so
#    CLI overrides stay authoritative.
args_prescan_profile "$@"
[[ -n ${PROFILE_PRELOAD:-} ]] && profile_load "$PROFILE_PRELOAD"

# 3) Explicit CLI flags
args_parse "$@"

# Quiet-hours gating (user can set QUIET_HOURS="22:00-07:00" in config).
if [[ -n ${QUIET_HOURS:-} ]] && (( ARG_YES )); then
    _now=$(date +%H%M)
    _from=$(printf '%s' "${QUIET_HOURS%%-*}" | tr -d :)
    _to=$(printf '%s'   "${QUIET_HOURS##*-}" | tr -d :)
    if (( _from < _to )); then
        (( _now >= _from && _now < _to )) && { echo "quiet hours, skipping"; exit 0; }
    else
        (( _now >= _from || _now < _to )) && { echo "quiet hours, skipping"; exit 0; }
    fi
fi

SUDO_KEEPALIVE_PID=0
_cleanup() {
    ui_monitor_stop
    if (( SUDO_KEEPALIVE_PID > 0 )); then
        kill "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    fi
    lock_release
}
trap _cleanup EXIT INT TERM

log_init

# Subcommand-style short-circuits.
(( ARG_HELP ))    && { cat "$EMERGER_LIB/help.txt"; exit 0; }
(( ARG_VERSION )) && { printf 'eMerger %s\n' "$EMERGER_VERSION"; exit 0; }
(( ARG_ERR ))     && { show_errors; exit 0; }
(( ARG_HISTORY )) && { show_history; exit 0; }
(( ARG_CHANGED )) && { diff_show; exit 0; }
(( ARG_DOCTOR ))  && { doctor_run; exit $?; }
(( ARG_LIST_PROFILES )) && { profile_list; exit 0; }
[[ -n $ARG_CHANGELOG ]] && { changelog_show "$ARG_CHANGELOG"; exit $?; }
(( ARG_UP ))      && { self_update "$EMERGER_ROOT"; exit $?; }
(( ARG_AU ))      && { setup_cron "$EMERGER_ROOT"; exit $?; }
(( ARG_RC ))      && { rm -rf "$EMERGER_CACHE"; mkdir -p "$EMERGER_CACHE"; ui_ok "Detection cache cleared"; }
[[ -n $ARG_REPORT ]] && { report_export "$ARG_REPORT"; exit $?; }
[[ -n $ARG_METRICS ]] && { metrics_export "$ARG_METRICS"; exit $?; }
(( ARG_ROLLBACK )) && { snapshot_rollback; exit $?; }
if (( ARG_REBOOT )); then
    reboot_check
    if (( REBOOT_NEEDED )); then
        ui_warn "Rebooting now."
        exec sudo reboot
    else
        ui_ok "No reboot needed."; exit 0
    fi
fi
(( ARG_INTERACTIVE )) && tui_menu

# First-run wizard (only if interactive and no config).
[[ ! -f $EMERGER_CONFIG/.wizard-done ]] && wizard_maybe_run

# Global lock.
if ! lock_acquire; then exit 1; fi

ignore_load
plugins_load
resume_load

# Build --only / --except filters (comma-separated manager names).
_arg_list_has() {
    local list="$1" item="$2" x
    IFS=',' read -r -a __al <<<"$list"
    for x in "${__al[@]}"; do
        [[ $x == "$item" ]] && return 0
    done
    return 1
}

main() {
    local start=$SECONDS

    if (( ARG_JSON )); then
        ARG_NO_LOGO=1; ARG_NO_INFO=1; QUIET_LEVEL=3
    fi

    if (( ! ARG_NO_LOGO )) && (( ! ARG_QUIET )); then
        ui_print_logo "$EMERGER_SRC/logo/logo.txt"
    fi

    if (( QUIET_LEVEL < 2 )); then
        if (( ! ARG_NO_INFO )); then
            ui_muted "$(sys_distro)  $(ui_glyph dot)  $(uname -m)  $(ui_glyph dot)  $(date '+%Y-%m-%d %H:%M')"
        fi
        ui_muted "eMerger v$EMERGER_VERSION  $(ui_glyph dot)  github.com/MasterCruelty/eMerger"
    fi

    if (( ARG_WEATHER )) && sys_has curl; then
        local w
        w=$(curl -sS --max-time 3 'https://wttr.in/?format=%l:+%c+%t+%w+%m' 2>/dev/null || true)
        [[ -n $w ]] && ui_muted "$w"
    fi

    ignore_advisory

    # Battery safety.
    if sys_on_battery; then
        local pct; pct=$(sys_battery_percent)
        if (( pct < 20 )) && (( ! ARG_YES )); then
            ui_warn "On battery at ${pct}%. Updates are I/O heavy."
            local ans
            read -r -p "    Continue anyway? [y/N]: " ans || ans=n
            [[ $ans == [yY]* ]] || { ui_muted "Aborted."; exit 0; }
        fi
    fi

    disk_precheck

    # sudo keep-alive only if some manager needs it.
    local need_sudo=0 m
    for m in "${PKG_MANAGERS[@]}"; do
        pkg_detect "$m" || continue
        pkg_is_dev "$m" && (( ! ARG_DEV )) && continue
        [[ $m == fwupd ]] && (( ! ARG_FIRMWARE )) && continue
        if pkg_needs_sudo "$m"; then need_sudo=1; break; fi
    done
    if (( need_sudo )) && (( ! DRY_RUN )) && ! sys_is_root; then
        if ! sudo -v; then
            ui_err "sudo authentication failed"
            exit 1
        fi
        ( while kill -0 "$$" 2>/dev/null; do sudo -n true 2>/dev/null; sleep 60; done ) &
        SUDO_KEEPALIVE_PID=$!
        disown "$SUDO_KEEPALIVE_PID" 2>/dev/null || true
    fi

    (( ARG_REFRESH_MIRRORS )) && mirrors_refresh
    (( ARG_SNAPSHOT ))        && snapshot_create

    # Snapshot installed packages for diff.
    diff_snapshot "$DIFF_BEFORE" 2>/dev/null || true

    hooks_run pre

    local detected=() parallel=() serial=()
    for m in "${PKG_MANAGERS[@]}"; do
        pkg_detect "$m" || continue
        if pkg_is_dev "$m" && (( ! ARG_DEV )); then continue; fi
        if [[ $m == fwupd ]]; then
            (( ARG_NO_FIRMWARE )) && continue
            (( ARG_FIRMWARE ))    || continue
        fi
        if (( ARG_RESUME )) && resume_has "$m"; then
            ui_muted "skip $m (resume)"; continue
        fi
        if [[ -n $ARG_ONLY ]] && ! _arg_list_has "$ARG_ONLY" "$m"; then
            continue
        fi
        if [[ -n $ARG_EXCEPT ]] && _arg_list_has "$ARG_EXCEPT" "$m"; then
            ui_muted "skip $m (--except)"; continue
        fi
        detected+=("$m")
        if (( ARG_PARALLEL )) && pkg_is_parallelizable "$m"; then
            parallel+=("$m")
        else
            serial+=("$m")
        fi
    done

    local total=${#detected[@]}
    (( total == 0 )) && ui_warn "No supported package managers detected."

    local idx=0
    for m in "${serial[@]}"; do
        idx=$((idx+1))
        ui_step "$idx" "$total" "$m"
        if pkg_run "$m"; then
            SUMMARY_MANAGERS+=("$m"); SUMMARY_RESULTS+=("ok")
            resume_mark "$m"
        else
            SUMMARY_MANAGERS+=("$m"); SUMMARY_RESULTS+=("fail")
            SUMMARY_ERRORS=$((SUMMARY_ERRORS+1))
        fi
    done

    if (( ${#parallel[@]} > 0 )); then
        ui_step "$((idx+1))" "$total" "parallel: ${parallel[*]}"
        local pids=() names=() logs=()
        for m in "${parallel[@]}"; do
            local lf="$EMERGER_STATE/parallel-$m.log"
            ( pkg_run "$m" >"$lf" 2>&1 ) &
            pids+=($!); names+=("$m"); logs+=("$lf")
        done
        local i
        for i in "${!pids[@]}"; do
            if wait "${pids[i]}"; then
                SUMMARY_MANAGERS+=("${names[i]}"); SUMMARY_RESULTS+=("ok")
                ui_done "${names[i]}"
                resume_mark "${names[i]}"
            else
                SUMMARY_MANAGERS+=("${names[i]}"); SUMMARY_RESULTS+=("fail")
                SUMMARY_ERRORS=$((SUMMARY_ERRORS+1))
                ui_fail "${names[i]}"
                tail -n 10 "${logs[i]}" | progress_highlight >&2 || true
            fi
        done
    fi

    (( ARG_NO_CACHE )) || clean_cache
    (( ARG_NO_TRASH )) || clean_trash

    hooks_run post

    # Post-snapshot diff.
    diff_snapshot "$DIFF_AFTER" 2>/dev/null || true
    diff_compute  "$DIFF_BEFORE" "$DIFF_AFTER" "$DIFF_LAST" 2>/dev/null || true

    summary_print $((SECONDS - start))
    notify_send_result

    # Restart ibus if it's running: updates to ibus/glib/gtk replace files on
    # disk while the daemon keeps the old versions mapped in memory, which
    # breaks input methods until the daemon is recycled. No-op if absent.
    if command -v ibus >/dev/null 2>&1 && pgrep -x ibus-daemon >/dev/null 2>&1; then
        ibus restart >/dev/null 2>&1 || true
    fi

    # Clean resume file on full success.
    if (( SUMMARY_ERRORS == 0 )); then
        resume_clear
    fi

    # Propagate failure upward.
    if (( SUMMARY_ERRORS > 0 )); then
        exit 3
    fi
    if (( ARG_REBOOT_EXIT )) && (( ${REBOOT_NEEDED:-0} == 1 )); then
        exit 4
    fi
}

main
