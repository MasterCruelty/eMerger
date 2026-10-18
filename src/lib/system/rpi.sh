#!/usr/bin/env bash
# Raspberry Pi board probes: model, EEPROM presence, power and thermal
# pre-flight.

# 1 = abort on under-voltage, even with -y.
: "${RPI_ABORT_ON_UNDERVOLTAGE:=0}"
: "${RPI_TEMP_WARN:=80}"   # °C

: "${RPI_MODEL_FILE:=/proc/device-tree/model}"

# Print the board model from RPI_MODEL_FILE without NUL bytes, empty when
# the file is unreadable.
rpi_model() {
    local model=""
    [[ -r $RPI_MODEL_FILE ]] && model=$(tr -d '\0' <"$RPI_MODEL_FILE" 2>/dev/null)
    printf '%s' "$model"
}

# Return 0 on a Raspberry Pi.
rpi_is_pi() { [[ $(rpi_model) == "Raspberry Pi"* ]]; }

# Return 0 on a board that boots from an SPI EEPROM: Pi 4, 400, 5, 500,
# CM4 or CM5.
rpi_has_eeprom() {
    local model; model=$(rpi_model)
    [[ $model =~ Raspberry\ Pi\ (4|400|5|500|Compute\ Module\ (4|5)) ]]
}

# Print the Pi's model, temperature and power state and warn about
# under-voltage and heat. Exit 1 on under-voltage with
# RPI_ABORT_ON_UNDERVOLTAGE=1 or a declined prompt. Return 0 off a Pi.
# vcgencmd get_throttled bits: 0 under-voltage, 1 freq capped, 2 throttled,
# 3 soft temp limit. Bits 16+ are the same, "since boot".
rpi_health_check() {
    rpi_is_pi || return 0
    sys_has vcgencmd || return 0
    local raw throttled temp="" temp_tenths=0
    raw=$(vcgencmd get_throttled 2>/dev/null) || return 0
    [[ $raw =~ throttled=(0x[0-9a-fA-F]+) ]] || return 0
    throttled=$(( BASH_REMATCH[1] ))
    if [[ $(vcgencmd measure_temp 2>/dev/null) =~ temp=([0-9]+)\.?([0-9]?) ]]; then
        temp="${BASH_REMATCH[1]}.${BASH_REMATCH[2]:-0}"
        temp_tenths=$(( BASH_REMATCH[1] * 10 + ${BASH_REMATCH[2]:-0} ))
    fi

    local power="power ok"
    (( throttled & 0x10000 )) && power="under-voltage since boot"
    (( throttled & 0x1 )) && power="UNDER-VOLTAGE"
    ui_muted "$(rpi_model)  $(ui_glyph dot)  ${temp:-?}°C  $(ui_glyph dot)  $power"
    log_info "rpi: throttled=$(printf '0x%x' "$throttled") temp=${temp:-?}"

    if (( throttled & 0x1 )); then
        ui_warn "The Pi is under-voltage right now, the power supply can't keep up."
        ui_muted "A brown-out while dpkg is writing can corrupt the SD card. Use the official PSU."
        if (( RPI_ABORT_ON_UNDERVOLTAGE )); then
            ui_err "Aborting (RPI_ABORT_ON_UNDERVOLTAGE=1)."; exit 1
        fi
        if (( ! ARG_YES )); then
            ui_confirm "Update anyway?" n || { ui_muted "Aborted."; exit 1; }
        fi
    elif (( throttled & 0x10000 )); then
        ui_warn "Under-voltage happened since boot; check the power supply and cable."
    fi
    if (( throttled & 0x4 )) || (( temp_tenths >= RPI_TEMP_WARN * 10 )); then
        ui_warn "SoC is hot (${temp:-?}°C) and may throttle; updates will be slower."
    fi
    return 0
}
