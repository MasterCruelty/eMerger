#!/usr/bin/env bash
# One-line stat of a step, parsed from a command's captured output.

# Print a one-line stat for manager $1 from its captured output file $2
# ("3 upgraded, 1 new, 0 removed"), nothing when no parser matches.
progress_summarize() {
    local manager="$1" file="$2"
    [[ -f $file ]] || { printf ''; return; }
    case "$manager" in
        apt)
            awk '/[0-9]+ upgraded/{for(i=1;i<=NF;i++)if($i=="upgraded,"){u=$(i-1)} for(i=1;i<=NF;i++)if($i=="newly"){n=$(i-1)} for(i=1;i<NF;i++)if($i=="to"&&$(i+1)~/^remove/){r=$(i-1)} printf "%s upgraded, %s new, %s removed", u+0, n+0, r+0; exit}' "$file"
            ;;
        pacman|yay|paru)
            local pkgs
            pkgs=$(grep -E '^Packages \([0-9]+\)' "$file" | tail -n1 | sed -E 's/^Packages \(([0-9]+)\).*/\1/')
            [[ -n $pkgs ]] && printf '%s packages' "$pkgs"
            ;;
        dnf|yum)
            awk '/^Upgrade +[0-9]+ Package/{print $2" upgraded"; exit} /^Install +[0-9]+ Package/{ins=$2} END{if(ins)print ins" installed"}' "$file"
            ;;
        flatpak)
            grep -cE '^Updating|^Installing' "$file" | awk '{if($1>0)print $1" refreshed"}'
            ;;
        snap)
            grep -cE 'refreshed' "$file" | awk '{if($1>0)print $1" refreshed"}'
            ;;
        *) : ;;
    esac
    return 0  # no match is not an error (set -e)
}

# Live progress. The monitor feeds every new output line to progress_feed,
# which sets PROGRESS_PERCENT (0-100, -1 unknown), PROGRESS_CURRENT/PROGRESS_TOTAL
# (0 unknown) and PROGRESS_MESSAGE (shown instead of the raw line). Runs once per
# output line: no forks in here.

# Clear the live progress state: percent and counters unknown, no message.
progress_reset() { PROGRESS_PERCENT=-1; PROGRESS_CURRENT=0; PROGRESS_TOTAL=0; PROGRESS_MESSAGE=""; }
progress_reset

# Set the counter to $1 of $2, both decimal digit strings (leading zeros
# allowed). Skip things like (0/0) or (9/3).
_progress_set_count() {
    local current=$(( 10#$1 )) total=$(( 10#$2 ))
    (( total > 0 && current <= total )) || return 0
    PROGRESS_CURRENT=$current; PROGRESS_TOTAL=$total; PROGRESS_PERCENT=-1
}

# Set PROGRESS_PERCENT to percentage $1 (decimals dropped, capped at 100) and
# clear the counter total. A value that is not a number is ignored.
_progress_set_percent() {
    local percent=${1%%.*}
    [[ $percent =~ ^[0-9]+$ ]] || return 0
    percent=$(( 10#$percent ))
    (( percent > 100 )) && percent=100
    PROGRESS_PERCENT=$percent; PROGRESS_TOTAL=0
}

# Update the PROGRESS_* globals from output line $2 of manager $1: its own
# format first, then the shared "(n/N)" and "[n/N]" forms. Never forks.
progress_feed() {
    local manager="$1" line="$2"
    case "$manager" in
        apt)
            # From -o APT::Status-Fd=1 (see pkg_run).
            if [[ $line =~ ^(dl|pm)status:[^:]*:([0-9.]+):(.*)$ ]]; then
                local kind=${BASH_REMATCH[1]} percent=${BASH_REMATCH[2]} message=${BASH_REMATCH[3]}
                # apt's byte percent can read 100 before the last file arrives.
                # The file counter cannot overshoot, so it drives the bar and
                # the message keeps only the text after it.
                if [[ $message =~ ^Retrieving\ file\ ([0-9]+)\ of\ ([0-9]+)\ *(.*)$ ]]; then
                    _progress_set_count "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                    message=${BASH_REMATCH[3]}
                    PROGRESS_MESSAGE="download${message:+ $message}"
                    return 0
                fi
                _progress_set_percent "$percent"
                if [[ $kind == dl ]]; then PROGRESS_MESSAGE="download: $message"; else PROGRESS_MESSAGE="$message"; fi
                return 0
            fi
            [[ $line =~ ^Progress:\ \[\ *([0-9]+)%\] ]] && _progress_set_percent "${BASH_REMATCH[1]}"
            ;;
        dnf|yum)
            # "  Upgrading : foo-1.2.x86_64    3/24"  and dnf5 "[ 3/24] ..."
            if [[ $line =~ ^\ +[A-Z][a-z]+[^:]*:\ .*[[:space:]]([0-9]+)/([0-9]+)[[:space:]]*$ ]]; then
                _progress_set_count "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
            elif [[ $line =~ ^\[\ *([0-9]+)/([0-9]+)\] ]]; then
                _progress_set_count "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
            elif [[ $line =~ ^\(([0-9]+)/([0-9]+)\): ]]; then
                _progress_set_count "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                PROGRESS_MESSAGE="download: ${line#*: }"
                return 0
            fi
            ;;
        emerge)
            # ">>> Emerging (3 of 24) app-misc/foo-1.2::gentoo"
            if [[ $line =~ \(([0-9]+)\ of\ ([0-9]+)\)\ (.*) ]]; then
                _progress_set_count "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
                PROGRESS_MESSAGE="${BASH_REMATCH[3]}"
                return 0
            fi
            ;;
        flatpak)
            # "Updating 2/5…" / "Installing 1/3…"
            if [[ $line =~ (Installing|Updating|Uninstalling)\ ([0-9]+)/([0-9]+) ]]; then
                _progress_set_count "${BASH_REMATCH[2]}" "${BASH_REMATCH[3]}"
            elif [[ $line =~ ([0-9]{1,3})%[[:space:]] ]]; then
                _progress_set_percent "${BASH_REMATCH[1]}"
            fi
            ;;
        snap|fwupd|softwareupdate|rustup)
            [[ $line =~ ([0-9]{1,3}(\.[0-9]+)?)\ ?% ]] && _progress_set_percent "${BASH_REMATCH[1]}"
            ;;
        brew)
            # "==> Upgrading 3 outdated packages:" then one "==> Upgrading foo" each.
            if [[ $line =~ ^==\>\ Upgrading\ ([0-9]+)\ outdated ]]; then
                # Read by the monitor.
                # shellcheck disable=SC2034
                PROGRESS_TOTAL=$(( 10#${BASH_REMATCH[1]} )); PROGRESS_CURRENT=0
                # Read by the monitor.
                # shellcheck disable=SC2034
                PROGRESS_PERCENT=-1
            elif [[ $line =~ ^==\>\ Upgrading\ (.+) ]]; then
                PROGRESS_CURRENT=$(( PROGRESS_CURRENT + 1 ))
                (( PROGRESS_TOTAL > 0 && PROGRESS_CURRENT > PROGRESS_TOTAL )) && PROGRESS_TOTAL=$PROGRESS_CURRENT
                PROGRESS_MESSAGE="upgrading ${BASH_REMATCH[1]}"
                return 0
            fi
            ;;
        gem)
            [[ $line =~ ^Updating\ ([^ ]+)$ ]] && { PROGRESS_CURRENT=$(( PROGRESS_CURRENT + 1 )); PROGRESS_MESSAGE="updating ${BASH_REMATCH[1]}"; return 0; }
            ;;
        cargo)
            [[ $line =~ ^Updating\ (.+)$ ]] && { PROGRESS_CURRENT=$(( PROGRESS_CURRENT + 1 )); PROGRESS_MESSAGE="updating ${BASH_REMATCH[1]}"; return 0; }
            ;;
        xbps)
            [[ $line =~ :\ updated\ successfully ]] && PROGRESS_CURRENT=$(( PROGRESS_CURRENT + 1 ))
            ;;
        eopkg)
            [[ $line =~ ^Downloading\ ([0-9]+)\ /\ ([0-9]+) ]] && _progress_set_count "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
            ;;
        nix)
            [[ $line =~ ^(copying\ path|building)\  ]] && PROGRESS_CURRENT=$(( PROGRESS_CURRENT + 1 ))
            ;;
        mas)
            [[ $line =~ ^==\>\ Installed ]] && PROGRESS_CURRENT=$(( PROGRESS_CURRENT + 1 ))
            ;;
    esac
    # Shared formats: pacman/yay/paru/zypper/apk "(3/24) upgrading foo",
    # zypper "Retrieving: foo (3/24)", and the "[3/24] foo" lines of the pip loop.
    if [[ $line =~ ^\(\ *([0-9]+)/([0-9]+)\)\ (.*) ]]; then
        _progress_set_count "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
        PROGRESS_MESSAGE="${BASH_REMATCH[3]}"
    elif [[ $line =~ ^\[\ *([0-9]+)/([0-9]+)\]\ (.*) ]]; then
        _progress_set_count "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
        # Read by the monitor.
        # shellcheck disable=SC2034
        PROGRESS_MESSAGE="${BASH_REMATCH[3]}"
    elif [[ $line =~ \(([0-9]+)/([0-9]+)\)[[:space:]]*$ ]]; then
        _progress_set_count "${BASH_REMATCH[1]}" "${BASH_REMATCH[2]}"
    fi
    return 0
}
