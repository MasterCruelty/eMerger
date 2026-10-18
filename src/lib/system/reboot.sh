#!/usr/bin/env bash
# Detect whether the system needs a reboot after updates.

REBOOT_IS_NEEDED=0
REBOOT_REASON=""
# Flag file Debian-family packages drop when a reboot is due. Tests reassign
# it after sourcing, the environment never sets it.
REBOOT_REQUIRED_FILE=/var/run/reboot-required

# Set REBOOT_IS_NEEDED and REBOOT_REASON. needs-restarting exits 1 when a
# reboot is due: any other failure (missing plugin, error) is unknown and
# claims nothing.
reboot_check() {
    REBOOT_IS_NEEDED=0; REBOOT_REASON=""
    if (( ${RPI_EEPROM_IS_PENDING:-0} )); then
        REBOOT_IS_NEEDED=1
        REBOOT_REASON="Raspberry Pi bootloader update staged"
        return 0
    fi
    if [[ -f $REBOOT_REQUIRED_FILE ]]; then
        REBOOT_IS_NEEDED=1
        REBOOT_REASON="$REBOOT_REQUIRED_FILE exists"
        if [[ -f $REBOOT_REQUIRED_FILE.pkgs ]]; then
            REBOOT_REASON+=" ($(wc -l <"$REBOOT_REQUIRED_FILE.pkgs") pkg(s))"
        fi
        return 0
    fi
    local rc
    if sys_has needs-restarting; then
        rc=0; needs-restarting -r >/dev/null 2>&1 || rc=$?
        if (( rc == 1 )); then
            REBOOT_IS_NEEDED=1
            REBOOT_REASON="needs-restarting -r says so"
            return 0
        fi
    fi
    if sys_has dnf; then
        rc=0; dnf -q needs-restarting -r >/dev/null 2>&1 || rc=$?
        if (( rc == 1 )); then
            REBOOT_IS_NEEDED=1; REBOOT_REASON="dnf needs-restarting"
        fi
    fi
    return 0
}

# Reboot now as root. Under --dry-run print the command and return 0,
# otherwise replace the shell and never return.
reboot_now() {
    local prefix
    prefix=$(sys_sudo_prefix)
    if (( DRY_RUN )); then
        ui_sub "[dry-run] would reboot: ${prefix:+$prefix }reboot ($REBOOT_REASON)"
        return 0
    fi
    ui_warn "Rebooting now."
    exec ${prefix:+"$prefix"} reboot
}

# Print the pending-reboot notice with the command that applies it.
reboot_advisory() {
    (( REBOOT_IS_NEEDED )) || return 0
    local prefix
    prefix=$(sys_sudo_prefix)
    printf '\n  %s%s Reboot recommended%s  %s%s%s\n' \
        "$C_YELLOW$C_BOLD" "$(ui_glyph warn)" "$C_RESET" \
        "$C_DIM$C_GRAY" "$REBOOT_REASON" "$C_RESET"
    printf '    %srun%s %s%sreboot%s  %sor%s %sup --reboot%s\n' \
        "$C_DIM$C_GRAY" "$C_RESET" "$C_BOLD" "${prefix:+$prefix }" "$C_RESET" "$C_DIM$C_GRAY" "$C_RESET" "$C_BOLD" "$C_RESET"
}
