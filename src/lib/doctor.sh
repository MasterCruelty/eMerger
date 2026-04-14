#!/usr/bin/env bash
# Health check: run `up --doctor` and see what's wrong with the environment.

_doctor_issue=0

_dok()   { ui_ok   "$*"; }
_dwarn() { ui_warn "$*"; _doctor_issue=$((_doctor_issue+1)); }
_derr()  { ui_err  "$*"; _doctor_issue=$((_doctor_issue+1)); }

doctor_run() {
    _doctor_issue=0
    ui_title "eMerger doctor"

    # Shell/env
    if [[ -n $BASH_VERSION ]]; then
        _dok "bash $BASH_VERSION"
    else
        _dwarn "running outside bash"
    fi

    # sudo
    if sys_is_root; then
        _dok "running as root"
    elif sudo -n true 2>/dev/null; then
        _dok "sudo cached"
    else
        ui_info "sudo: will prompt when needed"
    fi

    # Disk
    local free_mb; free_mb=$(df -Pm / | awk 'NR==2{print $4}')
    if [[ -n $free_mb ]] && (( free_mb < 1024 )); then
        _dwarn "low disk space on / (${free_mb}MB free)"
    else
        _dok "disk: ${free_mb:-?}MB free on /"
    fi

    # Network
    if sys_has curl && curl -fsS --max-time 4 -o /dev/null https://github.com 2>/dev/null; then
        _dok "network: reachable"
    elif sys_has curl; then
        _dwarn "network: github.com unreachable"
    fi

    # State dir writable
    if [[ -w $EMERGER_STATE ]] || mkdir -p "$EMERGER_STATE" 2>/dev/null; then
        _dok "state: $EMERGER_STATE writable"
    else
        _derr "state not writable: $EMERGER_STATE"
    fi

    # Package manager health
    local mgr
    for mgr in "${PKG_MANAGERS[@]}"; do
        pkg_detect "$mgr" || continue
        _doctor_pkg "$mgr"
    done

    # Reboot flag
    reboot_check
    if (( REBOOT_NEEDED )); then
        ui_warn "reboot pending ($REBOOT_REASON)"
    fi

    ui_hr
    if (( _doctor_issue == 0 )); then
        _dok "all clear"
        return 0
    fi
    ui_warn "$_doctor_issue issue(s) found"
    return 1
}

_doctor_pkg() {
    local m="$1"
    case "$m" in
        apt)
            if ! dpkg --audit 2>/dev/null | grep -q .; then
                _dok "apt: dpkg --audit clean"
            else
                _dwarn "apt: dpkg --audit reports issues"
            fi
            ;;
        pacman)
            if pacman -Dk >/dev/null 2>&1; then
                _dok "pacman: database ok"
            else
                _dwarn "pacman: database has issues (pacman -Dk)"
            fi
            ;;
        dnf|yum)
            if "$m" check --quiet >/dev/null 2>&1; then
                _dok "$m: check ok"
            else
                ui_info "$m: check not available or ran clean"
            fi
            ;;
        brew)
            if brew doctor >/dev/null 2>&1; then
                _dok "brew: doctor ok"
            else
                _dwarn "brew: doctor reports issues"
            fi
            ;;
        *)
            _dok "$m: detected"
            ;;
    esac
}
