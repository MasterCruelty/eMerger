#!/usr/bin/env bash
# Detect whether the system needs a reboot after updates.

REBOOT_NEEDED=0
REBOOT_REASON=""

reboot_check() {
    REBOOT_NEEDED=0; REBOOT_REASON=""
    if [[ -f /var/run/reboot-required ]]; then
        REBOOT_NEEDED=1
        REBOOT_REASON="/var/run/reboot-required exists"
        if [[ -f /var/run/reboot-required.pkgs ]]; then
            REBOOT_REASON+=" ($(wc -l </var/run/reboot-required.pkgs) pkg(s))"
        fi
        return
    fi
    if sys_has needs-restarting; then
        if ! needs-restarting -r >/dev/null 2>&1; then
            REBOOT_NEEDED=1
            REBOOT_REASON="needs-restarting -r says so"
            return
        fi
    fi
    if sys_has dnf && dnf -q needs-restarting -r >/dev/null 2>&1; then
        :
    elif sys_has dnf; then
        REBOOT_NEEDED=1; REBOOT_REASON="dnf needs-restarting"; return
    fi
    # Kernel version mismatch (running vs latest installed)
    local running latest=""
    running=$(uname -r)
    if sys_has pacman; then
        latest=$(pacman -Q linux 2>/dev/null | awk '{print $2}')
    elif sys_has dpkg-query; then
        latest=$(dpkg-query -W -f='${Version}' linux-image-generic 2>/dev/null || true)
    fi
    if [[ -n $latest ]] && [[ $running != *"$latest"* ]] && [[ -n $latest ]]; then
        : # informational only; don't force reboot just for this
    fi
}

reboot_advisory() {
    (( REBOOT_NEEDED )) || return 0
    printf '\n  %s%s REBOOT RECOMMENDED%s  %s%s%s\n' \
        "$C_YELLOW$C_BOLD" "$(ui_glyph warn)" "$C_RESET" \
        "$C_GRAY" "$REBOOT_REASON" "$C_RESET"
    printf '  %srun:%s sudo reboot\n' "$C_DIM" "$C_RESET"
}
