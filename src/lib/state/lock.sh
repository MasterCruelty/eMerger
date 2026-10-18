#!/usr/bin/env bash
# Global lock: prevent two concurrent eMerger runs from stepping on each other.
# One path per user, independent of the session environment, so a cron or
# timer run and an interactive run see the same lock.

# 1 while this process holds the mkdir fallback lock.
_LOCK_DIR_IS_HELD=0
# PID last read from the mkdir fallback lock, empty when none was written.
_LOCK_DIR_PID=""

# Take the lock "$EMERGER_STATE/emerger.lock", path kept in EMERGER_LOCK: flock on
# fd 9 when flock exists, else an atomic mkdir of "$EMERGER_LOCK.d". Return 1
# with a message when another run holds it or the lock path cannot be opened.
# Children must not inherit fd 9 (`9>&-`).
lock_acquire() {
    EMERGER_LOCK="$EMERGER_STATE/emerger.lock"
    if ! command -v flock >/dev/null 2>&1; then
        _lock_acquire_dir
        return
    fi
    # Append mode: a refused run must not truncate the holder's PID line.
    # Keep the braces: a bare `exec 9>>x 2>/dev/null` silences stderr for good.
    if ! { exec 9>>"$EMERGER_LOCK"; } 2>/dev/null; then
        ui_err "Cannot open the lock file $EMERGER_LOCK."
        return 1
    fi
    if ! flock -n 9; then
        _lock_refused "$(cat "$EMERGER_LOCK" 2>/dev/null)"
        { exec 9>&-; } 2>/dev/null || true
        return 1
    fi
    : >"$EMERGER_LOCK"
    printf '%d\n' "$$" >&9
    return 0
}

# Take the mkdir fallback lock, replacing it if its holder is gone. The
# replacement runs under a second mkdir lock ("$dir.break") and checks the
# holder again there, so two runs finding the same dead holder never both
# take over.
_lock_acquire_dir() {
    local dir="$EMERGER_LOCK.d" break_dir="$EMERGER_LOCK.d.break" rc=1
    if mkdir "$dir" 2>/dev/null; then
        _lock_dir_own "$dir"
        return 0
    fi
    if [[ ! -d $dir ]]; then
        ui_err "Cannot create the lock directory $dir."
        return 1
    fi
    if _lock_dir_is_live "$dir"; then
        _lock_refused "$_LOCK_DIR_PID"
        return 1
    fi
    if ! mkdir "$break_dir" 2>/dev/null; then
        # Clear a break lock left by a crash for the next run.
        _lock_dir_is_fresh "$break_dir" || rm -rf "$break_dir"
        _lock_refused "$_LOCK_DIR_PID"
        return 1
    fi
    if ! _lock_dir_is_live "$dir"; then
        rm -rf "$dir"
        mkdir "$dir" 2>/dev/null && _lock_dir_own "$dir" && rc=0
    fi
    rm -rf "$break_dir"
    (( rc == 0 )) || _lock_refused "$_LOCK_DIR_PID"
    return "$rc"
}

# Write this process's PID into lock directory $1 and mark the lock held.
_lock_dir_own() {
    printf '%d\n' "$$" >"$1/pid"
    _LOCK_DIR_IS_HELD=1
}

# Return 0 when lock directory $1 has a live holder: its PID answers
# `kill -0`, or no PID is written yet and the directory is fresh (the holder
# may be between its mkdir and its write). Set _LOCK_DIR_PID to the PID read.
_lock_dir_is_live() {
    _LOCK_DIR_PID=$(cat "$1/pid" 2>/dev/null || true)
    if [[ $_LOCK_DIR_PID =~ ^[0-9]+$ ]] && kill -0 "$_LOCK_DIR_PID" 2>/dev/null; then
        return 0
    fi
    [[ -z $_LOCK_DIR_PID ]] && _lock_dir_is_fresh "$1"
}

# Return 0 if directory $1 was modified less than 10 seconds ago. An
# unreadable age counts as old, so a lock left by a crash is still taken over.
_lock_dir_is_fresh() {
    local mtime now
    mtime=$(stat -c %Y -- "$1" 2>/dev/null || stat -f %m -- "$1" 2>/dev/null) || return 1
    now=$(date +%s 2>/dev/null) || return 1
    [[ $mtime =~ ^[0-9]+$ && $now =~ ^[0-9]+$ ]] || return 1
    (( now - mtime < 10 ))
}

# Report that the run holding the lock (PID $1, may be empty) blocks this one.
_lock_refused() {
    local pid="${1//[!0-9]/}"
    ui_err "Another eMerger run is in progress (PID ${pid:-unknown}, lock: $EMERGER_LOCK)."
    ui_muted "Wait for it to finish, or stop that process. Deleting the lock file does not release the lock."
}

# Release the lock if this process holds it.
lock_release() {
    { exec 9>&-; } 2>/dev/null || true
    if (( _LOCK_DIR_IS_HELD )); then
        rm -rf "$EMERGER_LOCK.d"
        _LOCK_DIR_IS_HELD=0
    fi
}
