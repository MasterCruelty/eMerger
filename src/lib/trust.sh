#!/usr/bin/env bash
# Ownership and mode checks for the user files eMerger sources or runs.

# Return 0 if file $1 and the directories holding it (the link's and, for a
# symlink, the target's) are owned by the effective uid and not writable by
# group or other: whoever can write the directory can swap the file. Write by
# the user's private group (named after the user, as a umask of 002
# produces) is accepted: no one else is in it. Otherwise print why with
# ui_warn and return 1.
trust_file() {
    local file="$1" target
    _trust_path "$file" || return 1
    _trust_path "$(dirname -- "$file")" || return 1
    if [[ -L $file ]]; then
        target=$(readlink -f -- "$file" 2>/dev/null) || target=""
        [[ -z $target ]] || _trust_path "$(dirname -- "$target")" || return 1
    fi
    return 0
}

# Check one path (symlinks followed) for trust_file: owner and write bits.
_trust_path() {
    local path="$1" stat_line uid gid mode euid="${EUID:-$(id -u)}" write_mask=8#022
    stat_line=$(stat -L -c '%u %g %a' -- "$path" 2>/dev/null || stat -L -f '%u %g %Lp' -- "$path" 2>/dev/null) || {
        ui_warn "$path: cannot read its owner and mode, not loaded"
        return 1
    }
    IFS=' ' read -r uid gid mode <<<"$stat_line"
    if [[ ! $uid =~ ^[0-9]+$ || ! $gid =~ ^[0-9]+$ || ! $mode =~ ^[0-7]+$ ]]; then
        ui_warn "$path: cannot read its owner and mode, not loaded"
        return 1
    fi
    if [[ $uid != "$euid" ]]; then
        ui_warn "$path is not owned by you (uid $uid, you are $euid), not loaded"
        return 1
    fi
    if [[ $gid == "$(id -g)" && $(id -gn) == "$(id -un)" ]]; then
        write_mask=8#002
    fi
    if (( 8#$mode & write_mask )); then
        ui_warn "$path is writable by group or other (mode $mode), not loaded. Fix: chmod go-w '$path'"
        return 1
    fi
    return 0
}

# Return 0 unless running as root with a HOME owned by another user (as
# `sudo -E` leaves it), in which case print why with ui_err and return 1.
trust_home() {
    sys_is_root || return 0
    local uid
    uid=$(stat -L -c %u -- "$HOME" 2>/dev/null || stat -L -f %u -- "$HOME" 2>/dev/null) || return 0
    [[ $uid == 0 ]] && return 0
    ui_err "Running as root with HOME=$HOME, owned by uid $uid."
    ui_muted "Its config, profiles, plugins and hooks would run as root. Run up as that user, or use sudo -H."
    return 1
}
