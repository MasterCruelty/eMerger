#!/usr/bin/env bash
# Raspberry Pi bootloader EEPROM recipe.

RPI_EEPROM_IS_PENDING=0

# Check the Pi bootloader with privilege prefix $1 and, only with --firmware
# (as fwupd), stage the update and set RPI_EEPROM_IS_PENDING.
# rpi-eeprom-update: 0 up to date, 1 update available, 2+ error.
rpi_eeprom_run() {
    local sudo_cmd="$1" rc=0 output
    if (( DRY_RUN )); then
        ui_sub "[dry-run] $sudo_cmd rpi-eeprom-update"
        return 0
    fi
    output=$($sudo_cmd rpi-eeprom-update 2>&1 9>&-) || rc=$?
    case $rc in
        0)
            ui_done "bootloader" "up to date"
            return 0
            ;;
        1)
            local current="" latest=""
            [[ $output =~ CURRENT:\ ([^$'\n']*)\ \( ]] && current=${BASH_REMATCH[1]}
            [[ $output =~ LATEST:\ ([^$'\n']*)\ \( ]] && latest=${BASH_REMATCH[1]}
            if (( ARG_FIRMWARE )); then
                if run_cmd "bootloader update" $sudo_cmd rpi-eeprom-update -a; then
                    # Read by the run loop.
                    # shellcheck disable=SC2034
                    RPI_EEPROM_IS_PENDING=1
                    ui_muted "staged; it is flashed on the next reboot"
                    return 0
                fi
                return 1
            fi
            ui_done "bootloader" "update available"
            [[ -n $latest ]] && ui_muted "current: ${current:-?}  ->  latest: $latest"
            ui_muted "apply it with: up --firmware"
            return 0
            ;;
        *)
            # Read by ui_done.
            # shellcheck disable=SC2034
            UI_LAST_ELAPSED=""
            ui_fail "bootloader check" "$rc"
            printf '%s\n' "$output" | tail -n 5 | sed "s/^/      $(ui_glyph v) /" >&2
            log_error "rpi-eeprom-update: rc=$rc"
            return "$rc"
            ;;
    esac
}
