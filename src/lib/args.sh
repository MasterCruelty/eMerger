#!/usr/bin/env bash
# Argument parser. Shift-based so flags can take values.

ARG_HELP=0; ARG_VERSION=0
ARG_UP=0; ARG_AU=0; ARG_ERR=0; ARG_RC=0; ARG_HISTORY=0
ARG_NO_LOGO=0; ARG_NO_INFO=0; ARG_NO_CACHE=0; ARG_NO_TRASH=0
ARG_WEATHER=0
ARG_QUIET=0; ARG_VERBOSE=0; ARG_DRY=0
ARG_INTERACTIVE=0
ARG_FIRMWARE=0; ARG_NO_FIRMWARE=0; ARG_DEV=0; ARG_SECURITY=0
ARG_YES=0; ARG_PARALLEL=0
ARG_NO_EMOJI=0
ARG_SNAPSHOT=0
ARG_REFRESH_MIRRORS=0
ARG_RESUME=0
ARG_CHANGED=0
ARG_DOCTOR=0
ARG_CHANGELOG=""
ARG_REPORT=""
ARG_PROFILE=""
ARG_LIST_PROFILES=0
ARG_REBOOT=0
ARG_JSON=0
ARG_REBOOT_EXIT=0
ARG_ROLLBACK=0
ARG_DOWNLOAD_ONLY=0
ARG_METRICS=""
ARG_ONLY=""
ARG_EXCEPT=""
QUIET_LEVEL=0

_missing_value() { printf 'Missing value for %s\n' "$1" >&2; exit 2; }

# Expand short-flag bundles: "-nv" -> "-n -v", "-ynv" -> "-y -n -v".
# Only bundles whose letters all map to known single-letter short flags are
# expanded; anything else is passed through unchanged so the main parser can
# still error on unknown flags.
_args_expand_bundles() {
    local a letters i ch expanded
    local -a out=()
    for a in "$@"; do
        # Known compound short flags that must stay atomic.
        case "$a" in
            -up|-au|-err|-rc|-nl|-ni|-nc|-nt|-qq|-qqq|-xyzzy|--*|-h|-V|-n|-v|-q|-y|-i|-w)
                out+=("$a"); continue ;;
        esac
        # Only consider single-dash, 3+ chars, no '=', no numerics.
        if [[ $a =~ ^-[A-Za-z]{2,}$ ]]; then
            letters="${a#-}"; expanded=1
            for (( i=0; i<${#letters}; i++ )); do
                ch="${letters:i:1}"
                case "$ch" in
                    h|V|n|v|q|y|i|w) : ;;
                    *) expanded=0; break ;;
                esac
            done
            if (( expanded )); then
                for (( i=0; i<${#letters}; i++ )); do
                    out+=("-${letters:i:1}")
                done
                continue
            fi
        fi
        out+=("$a")
    done
    printf '%s\n' "${out[@]}"
}

args_parse() {
    local -a argv=()
    if (( $# > 0 )); then
        mapfile -t argv < <(_args_expand_bundles "$@")
    fi
    set -- "${argv[@]}"
    while (( $# > 0 )); do
        case "$1" in
            -h|--help|-help)              ARG_HELP=1 ;;
            -V|--version)                 ARG_VERSION=1 ;;
            -up|--self-update)            ARG_UP=1 ;;
            -au|--auto-update)            ARG_AU=1 ;;
            -err|--errors)                ARG_ERR=1 ;;
            -rc|--rebuild-cache)          ARG_RC=1 ;;
            --history)                    ARG_HISTORY=1 ;;

            -nl|--no-logo)                ARG_NO_LOGO=1 ;;
            -ni|--no-info)                ARG_NO_INFO=1 ;;
            -nc|--no-cache)               ARG_NO_CACHE=1 ;;
            -nt|--no-trash)               ARG_NO_TRASH=1 ;;
            -w|--weather)                 ARG_WEATHER=1 ;;

            -q|--quiet)                   ARG_QUIET=1; QUIET_LEVEL=$(( QUIET_LEVEL + 1 )) ;;
            -qq)                          ARG_QUIET=1; QUIET_LEVEL=2 ;;
            -qqq)                         ARG_QUIET=1; QUIET_LEVEL=3 ;;
            -v|--verbose)                 ARG_VERBOSE=1; UI_VERBOSE=1 ;;
            -n|--dry-run)                 ARG_DRY=1; DRY_RUN=1 ;;
            -i|--interactive)             ARG_INTERACTIVE=1 ;;

            --firmware)                   ARG_FIRMWARE=1 ;;
            --no-firmware)                ARG_NO_FIRMWARE=1 ;;
            --dev)                        ARG_DEV=1 ;;
            --security)                   ARG_SECURITY=1 ;;
            -y|--yes)                     ARG_YES=1 ;;
            --parallel)                   ARG_PARALLEL=1 ;;
            --no-emoji)                   ARG_NO_EMOJI=1; ui_reinit ;;

            --snapshot)                   ARG_SNAPSHOT=1 ;;
            --refresh-mirrors)            ARG_REFRESH_MIRRORS=1 ;;
            --resume)                     ARG_RESUME=1 ;;
            --changed)                    ARG_CHANGED=1 ;;
            --reboot)                     ARG_REBOOT=1 ;;
            --reboot-exit)                ARG_REBOOT_EXIT=1 ;;
            --rollback)                   ARG_ROLLBACK=1 ;;
            --download-only|--offline)    ARG_DOWNLOAD_ONLY=1 ;;
            --json)                       ARG_JSON=1 ;;

            --doctor)                     ARG_DOCTOR=1 ;;
            --list-profiles)              ARG_LIST_PROFILES=1 ;;

            --profile)                    shift; [[ $# -gt 0 ]] || _missing_value --profile; ARG_PROFILE="$1" ;;
            --profile=*)                  ARG_PROFILE="${1#*=}" ;;
            --changelog)                  shift; [[ $# -gt 0 ]] || _missing_value --changelog; ARG_CHANGELOG="$1" ;;
            --changelog=*)                ARG_CHANGELOG="${1#*=}" ;;
            --report)                     shift; [[ $# -gt 0 ]] || _missing_value --report; ARG_REPORT="$1" ;;
            --report=*)                   ARG_REPORT="${1#*=}" ;;
            --metrics)                    shift; [[ $# -gt 0 ]] || _missing_value --metrics; ARG_METRICS="$1" ;;
            --metrics=*)                  ARG_METRICS="${1#*=}" ;;
            --only)                       shift; [[ $# -gt 0 ]] || _missing_value --only; ARG_ONLY="$1" ;;
            --only=*)                     ARG_ONLY="${1#*=}" ;;
            --except)                     shift; [[ $# -gt 0 ]] || _missing_value --except; ARG_EXCEPT="$1" ;;
            --except=*)                   ARG_EXCEPT="${1#*=}" ;;

            -xyzzy)
                printf "Let's keep its memory alive.\n"; exit 0 ;;
            --)                           shift; break ;;
            *)
                printf 'Unknown argument: %s (try "up --help")\n' "$1" >&2
                exit 2
                ;;
        esac
        shift
    done
}

# Pre-scan for --profile so the profile file can set defaults BEFORE the
# explicit CLI flags parsed by args_parse take effect (CLI wins).
args_prescan_profile() {
    local i argv=("$@")
    for (( i=0; i<${#argv[@]}; i++ )); do
        case "${argv[i]}" in
            --profile=*) PROFILE_PRELOAD="${argv[i]#*=}"; return ;;
            --profile)   PROFILE_PRELOAD="${argv[i+1]:-}"; return ;;
        esac
    done
    PROFILE_PRELOAD=""
}
