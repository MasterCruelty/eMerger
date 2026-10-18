#!/usr/bin/env bash
# Argument parser. Shift-based so flags can take values.
# ARG_* are read by the modules that act on them.
# shellcheck disable=SC2034

ARG_HELP=0; ARG_VERSION=0
ARG_SELF_UPDATE=0; ARG_AUTO_UPDATE=0; ARG_ERRORS=0; ARG_REBUILD_CACHE=0; ARG_HISTORY=0
ARG_NO_LOGO=0; ARG_NO_INFO=0; ARG_KEEP_CACHE=0; ARG_KEEP_TRASH=0; ARG_DEEP_CLEAN=0
ARG_WEATHER=0
ARG_FIRMWARE=0; ARG_NO_FIRMWARE=0; ARG_DEV=0; ARG_SECURITY=0
ARG_YES=0; ARG_PARALLEL=0
ARG_ASCII=0
ARG_SNAPSHOT=0
ARG_REFRESH_MIRRORS=0
ARG_RESUME=0
ARG_CHANGED=0
ARG_DOCTOR=0
ARG_CHANGELOG=""
ARG_LIST_PROFILES=0
ARG_REBOOT=0
ARG_JSON=0
ARG_REBOOT_EXIT=0
ARG_ROLLBACK=0
ARG_DOWNLOAD_ONLY=0
ARG_ACCEPT_LICENSES=0
ARG_METRICS=""
ARG_ONLY=""
ARG_EXCEPT=""
QUIET_LEVEL=0

# Print "Missing value for" flag $1 to stderr and exit 2.
_args_missing_value() { printf 'Missing value for %s\n' "$1" >&2; exit 2; }

# Exit 2 when value $2 of flag $1 is empty: an empty filter or path would
# otherwise widen the run to everything.
_args_require_value() {
    [[ -n $2 ]] || _args_missing_value "$1"
}

# Return 0 if comma-separated list $1 names item $2. Spaces around each name
# are ignored ("apt, flatpak").
args_list_has() {
    local list="$1" item="$2" name
    local -a items=()
    IFS=',' read -r -a items <<<"$list"
    for name in "${items[@]}"; do
        name=${name#"${name%%[![:space:]]*}"}
        name=${name%"${name##*[![:space:]]}"}
        [[ $name == "$item" ]] && return 0
    done
    return 1
}

# Set _ARGS_EXPANDED to arguments $@ with short-flag bundles expanded: "-nv" ->
# "-n -v". Only bundles made of known single-letter flags expand, anything
# else passes through unchanged so args_parse still refuses unknown flags.
_args_expand_bundles() {
    local arg letters i letter is_expanded
    _ARGS_EXPANDED=()
    for arg in "$@"; do
        # Known compound short flags that must stay atomic.
        case "$arg" in
            -up|-au|-err|-rc|-nl|-ni|-nc|-nt|-qq|-qqq|--*|-h|-V|-n|-v|-q|-y|-w)
                _ARGS_EXPANDED+=("$arg"); continue ;;
        esac
        # Only consider single-dash, 3+ chars, no '=', no numerics.
        if [[ $arg =~ ^-[A-Za-z]{2,}$ ]]; then
            letters="${arg#-}"; is_expanded=1
            for (( i=0; i<${#letters}; i++ )); do
                letter="${letters:i:1}"
                case "$letter" in
                    h|V|n|v|q|y|w) : ;;
                    *) is_expanded=0; break ;;
                esac
            done
            if (( is_expanded )); then
                for (( i=0; i<${#letters}; i++ )); do
                    _ARGS_EXPANDED+=("-${letters:i:1}")
                done
                continue
            fi
        fi
        _ARGS_EXPANDED+=("$arg")
    done
}

# Set the ARG_* globals, QUIET_LEVEL, UI_VERBOSE and DRY_RUN from argument
# list $@. Exit 2 on an unknown flag or a value flag without its value.
args_parse() {
    # Actions and queries come from the command line only: config.sh and
    # profiles hold settings, so a stray ARG_SELF_UPDATE=1 there cannot run
    # an update of eMerger itself, or anything else, on every run.
    ARG_HELP=0; ARG_VERSION=0; ARG_SELF_UPDATE=0; ARG_AUTO_UPDATE=0; ARG_ERRORS=0
    ARG_REBUILD_CACHE=0; ARG_HISTORY=0; ARG_DOCTOR=0; ARG_LIST_PROFILES=0
    ARG_CHANGED=0; ARG_CHANGELOG=""; ARG_METRICS=""; ARG_ROLLBACK=0; ARG_REBOOT=0
    _ARGS_EXPANDED=()
    if (( $# > 0 )); then
        _args_expand_bundles "$@"
    fi
    set -- "${_ARGS_EXPANDED[@]}"
    while (( $# > 0 )); do
        # Read a value flag's --flag=VALUE form as --flag VALUE.
        case "$1" in
            --profile=*|--changelog=*|--metrics=*|--only=*|--except=*)
                set -- "${1%%=*}" "${1#*=}" "${@:2}" ;;
        esac
        case "$1" in
            -h|--help)                    ARG_HELP=1 ;;
            -V|--version)                 ARG_VERSION=1 ;;
            -up|--self-update)            ARG_SELF_UPDATE=1 ;;
            -au|--auto-update)            ARG_AUTO_UPDATE=1 ;;
            -err|--errors)                ARG_ERRORS=1 ;;
            -rc|--rebuild-cache)          ARG_REBUILD_CACHE=1 ;;
            --history)                    ARG_HISTORY=1 ;;

            -nl|--no-logo)                ARG_NO_LOGO=1 ;;
            -ni|--no-info)                ARG_NO_INFO=1 ;;
            -nc|--keep-cache)             ARG_KEEP_CACHE=1 ;;
            -nt|--keep-trash)             ARG_KEEP_TRASH=1 ;;
            --deep-clean)                 ARG_DEEP_CLEAN=1 ;;
            -w|--weather)                 ARG_WEATHER=1 ;;

            -q|--quiet)                   QUIET_LEVEL=$(( QUIET_LEVEL + 1 )) ;;
            -qq)                          QUIET_LEVEL=2 ;;
            -qqq)                         QUIET_LEVEL=3 ;;
            -v|--verbose)                 UI_VERBOSE=1 ;;
            -n|--dry-run)                 DRY_RUN=1 ;;

            --firmware)                   ARG_FIRMWARE=1 ;;
            --no-firmware)                ARG_NO_FIRMWARE=1 ;;
            --dev)                        ARG_DEV=1 ;;
            --security)                   ARG_SECURITY=1 ;;
            -y|--yes)                     ARG_YES=1 ;;
            --parallel)                   ARG_PARALLEL=1 ;;
            --ascii)                      ARG_ASCII=1; ui_reinit ;;

            --snapshot)                   ARG_SNAPSHOT=1 ;;
            --refresh-mirrors)            ARG_REFRESH_MIRRORS=1 ;;
            --resume)                     ARG_RESUME=1 ;;
            --changed)                    ARG_CHANGED=1 ;;
            --reboot)                     ARG_REBOOT=1 ;;
            --reboot-exit)                ARG_REBOOT_EXIT=1 ;;
            --rollback)                   ARG_ROLLBACK=1 ;;
            --download-only)              ARG_DOWNLOAD_ONLY=1 ;;
            --accept-licenses)            ARG_ACCEPT_LICENSES=1 ;;
            --json)                       ARG_JSON=1 ;;

            --doctor)                     ARG_DOCTOR=1 ;;
            --list-profiles)              ARG_LIST_PROFILES=1 ;;

            --profile)                    shift; _args_require_value --profile "${1:-}" ;;
            --changelog)                  shift; _args_require_value --changelog "${1:-}"; ARG_CHANGELOG="$1" ;;
            --metrics)                    shift; _args_require_value --metrics "${1:-}"; ARG_METRICS="$1" ;;
            --only)                       shift; _args_require_value --only "${1:-}"; ARG_ONLY="$1" ;;
            # --except appends to the list from config.sh or the profile.
            --except)                     shift; _args_require_value --except "${1:-}"; ARG_EXCEPT="${ARG_EXCEPT:+$ARG_EXCEPT,}$1" ;;

            --)                           shift; break ;;
            *)
                printf 'Unknown argument: %s (try "up --help")\n' "$1" >&2
                exit 2
                ;;
        esac
        shift
    done
}

# Set PROFILE_PRELOAD to the last --profile of argument list $@ (args_parse
# keeps the last too), read before args_parse so explicit flags override the
# profile's defaults. Words after -- are not read.
args_prescan_profile() {
    local i argv=("$@")
    PROFILE_PRELOAD=""
    for (( i=0; i<${#argv[@]}; i++ )); do
        case "${argv[i]}" in
            --profile=*) PROFILE_PRELOAD="${argv[i]#*=}" ;;
            --profile)   PROFILE_PRELOAD="${argv[i+1]:-}"; i=$(( i + 1 )) ;;
            --)          return ;;
        esac
    done
}
