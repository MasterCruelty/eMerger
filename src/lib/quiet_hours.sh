#!/usr/bin/env bash
# Quiet hours: an unattended run (-y) inside QUIET_HOURS does nothing.

# Exit 0 printing "quiet hours, skipping" when -y is set and the clock is
# inside QUIET_HOURS ("22:00-07:00", may wrap past midnight). A malformed
# value is warned about and ignored.
quiet_hours_check() {
    # Times compare as base-10 HHMM: a leading zero must not read as octal.
    if [[ -n ${QUIET_HOURS:-} ]] && (( ARG_YES )); then
        _hm='([01]?[0-9]|2[0-3]):([0-5][0-9])'
        if [[ $QUIET_HOURS =~ ^$_hm-$_hm$ ]]; then
            _from=$(( 10#${BASH_REMATCH[1]} * 100 + 10#${BASH_REMATCH[2]} ))
            _to=$(( 10#${BASH_REMATCH[3]} * 100 + 10#${BASH_REMATCH[4]} ))
            _now=$(date +%H%M)
            [[ $_now =~ ^[0-9]{4}$ ]] || _now=0
            _now=$(( 10#$_now ))
            if (( _from < _to )); then
                (( _now >= _from && _now < _to )) && { echo "quiet hours, skipping"; exit 0; }
            else
                (( _now >= _from || _now < _to )) && { echo "quiet hours, skipping"; exit 0; }
            fi
        else
            ui_warn "QUIET_HOURS=\"$QUIET_HOURS\" is not HH:MM-HH:MM, ignored"
        fi
    fi
    return 0
}
