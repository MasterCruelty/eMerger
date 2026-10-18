#!/usr/bin/env bash
# --parallel: the managers that can run side by side, as one step.

# PIDs of the --parallel managers still running.
_PARALLEL_PIDS=()

# Run managers $3... side by side as step $1 of $2, each logging to
# $EMERGER_STATE/parallel-<manager>.log, then record each result. The
# interrupt handler stops the PIDs in _PARALLEL_PIDS.
run_parallel() {
    local step="$1" total="$2"; shift 2
    local -a parallel=("$@")
    local manager
    ui_step "$step" "$total"
    local joined; printf -v joined '%s ' "${parallel[@]}"
    ui_title "parallel: ${joined% }"
    local pids=() names=() logs=() exit_codes=()
    for manager in "${parallel[@]}"; do
        local log_file="$EMERGER_STATE/parallel-$manager.log"
        # `||` keeps errexit off inside pkg_run, as in a serial run, so a
        # failing step is retried and logged instead of ending the subshell.
        # Its own capture file is removed when the run is interrupted.
        ( trap 'run_cmd_cleanup; exit 1' INT TERM
          # Read by the ui functions in this subshell.
          # shellcheck disable=SC2034
          UI_IS_TTY=0; start=$SECONDS; rc=0
          pkg_run "$manager" >"$log_file" 2>&1 || rc=$?
          printf '%d\n' $(( SECONDS - start )) >"$log_file.secs"
          exit "$rc" ) 9>&- &
        pids+=($!); names+=("$manager"); logs+=("$log_file")
    done
    _PARALLEL_PIDS=("${pids[@]}")
    ui_monitor_start "running ${#parallel[@]} managers" "${logs[0]}"
    local i secs
    for i in "${!pids[@]}"; do
        if wait "${pids[i]}"; then exit_codes[i]=0; else exit_codes[i]=$?; fi
    done
    _PARALLEL_PIDS=()
    ui_monitor_stop
    # Read by ui_done.
    # shellcheck disable=SC2034
    UI_LAST_ELAPSED=""
    for i in "${!pids[@]}"; do
        secs=$(cat "${logs[i]}.secs" 2>/dev/null || true)
        [[ $secs =~ ^[0-9]+$ ]] || secs=0
        rm -f "${logs[i]}.secs"
        if (( exit_codes[i] == 0 )); then
            summary_add "${names[i]}" ok "$secs"
            ui_done "${names[i]}"
            resume_mark "${names[i]}"
        else
            summary_add "${names[i]}" fail "$secs"
            ui_fail "${names[i]}" "${exit_codes[i]}"
            tail -n 10 "${logs[i]}" | run_sanitize | ui_highlight >&2 || true
        fi
    done
}
