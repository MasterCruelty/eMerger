#!/usr/bin/env bash
# Validation of numeric knobs read from the environment, config or profile.

# Normalise numeric knob $1 to a base-10 whole number, or set it to default
# $2 with a warning when it holds anything else (it is later evaluated in
# arithmetic, where text would run as code). Empty means the default.
knob_int() {
    local name="$1" default="$2" value="${!1:-}"
    if [[ $value =~ ^[0-9]{1,15}$ ]]; then
        printf -v "$name" '%d' "$(( 10#$value ))"
        return 0
    fi
    [[ -n $value ]] && ui_warn "$name=\"$value\" is not a whole number, using $default"
    printf -v "$name" '%s' "$default"
}

# Normalise safety switch $1 (a knob whose 0 is the unsafe side) to a base-10
# whole number, empty meaning 0. Any other value exits 2: guessing could turn
# a misspelt dry run into a real upgrade.
knob_switch() {
    local name="$1" value="${!1:-}"
    if [[ -z $value ]]; then
        printf -v "$name" '%d' 0
    elif [[ $value =~ ^[0-9]{1,15}$ ]]; then
        printf -v "$name" '%d' "$(( 10#$value ))"
    else
        ui_err "$name=\"$value\" is not a whole number (0 or 1)."
        exit 2
    fi
}

# Validate every numeric knob and safety switch from the environment, config
# or profile, before any arithmetic reads them.
knobs_validate() {
    for _knob in DISK_MIN_FREE_MB:1024 BATTERY_MIN_PCT:20 RPI_TEMP_WARN:80 \
            RETRY_ATTEMPTS:2 RETRY_DELAY:3 CACHE_MENU_ROWS:12 \
            EMERGER_CACHE_TTL:86400 EMERGER_PROMPT_TIMEOUT:60 MANAGER_TIMEOUT:0 \
            UI_VERBOSE:0 ARG_ASCII:0; do
        knob_int "${_knob%%:*}" "${_knob#*:}"
    done
    # Safety switches refuse what they cannot read.
    for _knob in DRY_RUN RPI_ABORT_ON_UNDERVOLTAGE; do
        knob_switch "$_knob"
    done
}
