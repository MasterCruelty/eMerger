#!/usr/bin/env bash
# Health check: run `up --doctor` and see what's wrong with the environment.

_DOCTOR_ISSUE_COUNT=0

# Print a finding: ok, or a warning or error that counts as an issue.
_doctor_ok()   { ui_ok   "$*"; }
_doctor_warn() { ui_warn "$*"; _DOCTOR_ISSUE_COUNT=$((_DOCTOR_ISSUE_COUNT+1)); }
_doctor_error()  { ui_err  "$*"; _DOCTOR_ISSUE_COUNT=$((_DOCTOR_ISSUE_COUNT+1)); }

# Check the environment, print every finding and return 1 when any is an
# issue.
doctor_run() {
    _DOCTOR_ISSUE_COUNT=0
    ui_title "eMerger doctor"

    _doctor_shell
    _doctor_sudo
    _doctor_disk
    _doctor_network
    _doctor_state
    _doctor_glyphs
    _doctor_managers
    _doctor_reboot

    ui_rule
    if (( _DOCTOR_ISSUE_COUNT == 0 )); then
        _doctor_ok "all clear"
        return 0
    fi
    ui_warn "$_DOCTOR_ISSUE_COUNT issue(s) found"
    return 1
}

# Run manager $1's own health check and report it, counting a warning as an
# issue. A check the installed version lacks is informational only.
_doctor_pkg() {
    local manager="$1" out rc
    case "$manager" in
        apt)
            # Captured whole: `| grep -q` would SIGPIPE dpkg on long output.
            out=$(dpkg --audit 2>/dev/null || true)
            if [[ -z $out ]]; then
                _doctor_ok "apt: dpkg --audit clean"
            else
                _doctor_warn "apt: dpkg --audit reports issues"
            fi
            ;;
        pacman)
            if pacman -Dk >/dev/null 2>&1; then
                _doctor_ok "pacman: database ok"
            else
                _doctor_warn "pacman: database has issues (pacman -Dk)"
            fi
            ;;
        dnf|yum)
            rc=0; out=$("$manager" check --quiet 2>&1) || rc=$?
            if (( rc == 0 )); then
                _doctor_ok "$manager: check ok"
            elif [[ $out == *"No such command"* || $out == *"Unknown argument"* ]]; then
                ui_info "$manager: check not available"
            else
                _doctor_warn "$manager: check reports problems ($manager check)"
            fi
            ;;
        brew)
            if brew doctor >/dev/null 2>&1; then
                _doctor_ok "brew: doctor ok"
            else
                _doctor_warn "brew: doctor reports issues"
            fi
            ;;
        *)
            _doctor_ok "$manager: detected"
            ;;
    esac
}

# Report the shell running eMerger.
_doctor_shell() {
    if [[ -n $BASH_VERSION ]]; then
        _doctor_ok "bash $BASH_VERSION"
    else
        _doctor_warn "running outside bash"
    fi
}

# Report whether commands can run as root without a prompt.
_doctor_sudo() {
    if sys_is_root; then
        _doctor_ok "running as root"
    elif sudo -n true 2>/dev/null; then
        _doctor_ok "sudo cached"
    else
        ui_info "sudo: will prompt when needed"
    fi
}

# Warn about low free space on /.
_doctor_disk() {
    # Same threshold as the run's pre-flight check.
    local free_mb; free_mb=$(sys_free_space m /)
    if [[ -n $free_mb ]] && (( free_mb < ${DISK_MIN_FREE_MB:-1024} )); then
        _doctor_warn "low disk space on / (${free_mb}MB free)"
    else
        _doctor_ok "disk: ${free_mb:-?}MB free on /"
    fi
}

# Report whether github.com answers, when curl is installed.
_doctor_network() {
    if sys_has curl && curl -fsS --max-time 4 -o /dev/null https://github.com 2>/dev/null; then
        _doctor_ok "network: reachable"
    elif sys_has curl; then
        _doctor_warn "network: github.com unreachable"
    fi
}

# Report whether the state directory is writable.
_doctor_state() {
    if [[ -w $EMERGER_STATE ]] || mkdir -p "$EMERGER_STATE" 2>/dev/null; then
        _doctor_ok "state: $EMERGER_STATE writable"
    else
        _doctor_error "state not writable: $EMERGER_STATE"
    fi
}

# Report the glyph mode and how to get emoji icons.
_doctor_glyphs() {
    if (( ! UI_HAS_UNICODE )); then
        ui_info "terminal: ASCII mode (no UTF-8 locale or --ascii)"
    elif (( UI_HAS_EMOJI )); then
        _doctor_ok "terminal: UTF-8 + emoji font"
    else
        ui_info "terminal: no emoji font, using plain symbols"
        if sys_has apt; then
            ui_muted "for emoji icons: sudo apt install fonts-noto-color-emoji"
        elif sys_has pacman; then
            ui_muted "for emoji icons: sudo pacman -S noto-fonts-emoji"
        elif sys_has dnf; then
            ui_muted "for emoji icons: sudo dnf install google-noto-emoji-color-fonts"
        fi
    fi
}

# Run the health check of every detected manager.
_doctor_managers() {
    local manager
    for manager in "${PKG_MANAGERS[@]}"; do
        pkg_detect "$manager" || continue
        _doctor_pkg "$manager"
    done
}

# Warn about a pending reboot.
_doctor_reboot() {
    reboot_check
    if (( REBOOT_IS_NEEDED )); then
        ui_warn "reboot pending ($REBOOT_REASON)"
    fi
}
