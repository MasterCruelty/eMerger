#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    setup_minbin
}

teardown() {
    teardown_env
}

stub_vcgencmd() {
    cat >"$STUBS/vcgencmd" <<EOF
#!/bin/sh
case "\$1" in
    get_throttled) echo "throttled=$1" ;;
    measure_temp)  echo "temp=$2'C" ;;
esac
EOF
    chmod +x "$STUBS/vcgencmd"
    echo "Raspberry Pi 5 Model B Rev 1.0" >"$HOME/model"
}

@test "safety prompt: declining the Pi under-voltage prompt exits 1" {
    command -v setsid >/dev/null || skip "setsid not available"
    echo 'Raspberry Pi 4 Model B' >"$HOME/model"
    stub vcgencmd 'case "$1" in get_throttled) echo throttled=0x1;; measure_temp) echo "temp=50.0'"'"'C";; esac'
    run setsid -w bash -c 'set -uo pipefail; EMERGER_STATE=$HOME/st; EMERGER_LOG=$HOME/st/log; mkdir -p $HOME/st
        RPI_MODEL_FILE=$HOME/model; ARG_YES=0
        source "$LIB/load.sh" ui log sys rpi rpi_eeprom
        rpi_health_check; echo continued' </dev/null
    [ "$status" -eq 1 ]
    [[ "$output" == *"Aborted"* ]]
    [[ "$output" != *"continued"* ]]
}

@test "safety prompt: declining the low-battery prompt exits 1" {
    command -v setsid >/dev/null || skip "setsid not available"
    run setsid -w bash -c 'set -uo pipefail; EMERGER_STATE=$HOME/st; EMERGER_LOG=$HOME/st/log; mkdir -p $HOME/st
        ARG_YES=0
        source "$LIB/load.sh" ui log sys preflight
        sys_is_on_battery() { return 0; }; sys_battery_percent() { echo 5; }
        battery_precheck; echo continued' </dev/null
    [ "$status" -eq 1 ]
    [[ "$output" == *"Aborted"* ]]
    [[ "$output" != *"continued"* ]]
}

@test "battery: macOS pmset reports battery power and percent" {
    stub pmset "printf \"Now drawing from 'Battery Power'\\n -InternalBattery-0 (id=1)\\t15%%; discharging; 1:02 remaining\\n\""
    run sys_lib 'SYS_POWER_DIR=$HOME/none; sys_is_on_battery && echo on; sys_battery_percent'
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "on" ]
    [ "${lines[1]}" = "15" ]
    stub pmset "printf \"Now drawing from 'AC Power'\\n\""
    run sys_lib 'SYS_POWER_DIR=$HOME/none; sys_is_on_battery || echo off; sys_battery_percent'
    [ "${lines[0]}" = "off" ]
    [ "${lines[1]}" = "100" ]
}

@test "battery: Linux AC online means not on battery" {
    mkdir -p "$HOME/ps/AC" "$HOME/ps/BAT0"
    echo 1 >"$HOME/ps/AC/online"; echo 42 >"$HOME/ps/BAT0/capacity"
    run sys_lib 'SYS_POWER_DIR=$HOME/ps; sys_is_on_battery || echo off; sys_battery_percent'
    [ "${lines[0]}" = "off" ]
    [ "${lines[1]}" = "42" ]
    echo 0 >"$HOME/ps/AC/online"
    run sys_lib 'SYS_POWER_DIR=$HOME/ps; sys_is_on_battery && echo on'
    [ "$output" = "on" ]
}

@test "sys_free_space: prints the free column in the block size asked, empty when df fails" {
    stub df 'echo "Filesystem Blocks Used Available Capacity Mounted"; echo "/dev/x 9 1 7$1$2 50% /"'
    run sys_lib 'sys_free_space k /; sys_free_space m /home'
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%s\n' '7-Pk/' '7-Pm/home')" ]
    stub df 'exit 1'
    run sys_lib 'v=$(sys_free_space k /); echo "[$v] rc=$?"'
    [ "$output" = "[] rc=0" ]
}

@test "battery: non-numeric capacity is never evaluated, the reading falls back" {
    mkdir -p "$HOME/ps/AC" "$HOME/ps/BAT0"
    echo 0 >"$HOME/ps/AC/online"
    echo 'BASH_VERSINFO[$(touch $HOME/pwned-bat)]' >"$HOME/ps/BAT0/capacity"
    run sys_lib 'source "$LIB/load.sh" preflight; SYS_POWER_DIR=$HOME/ps; ARG_YES=1
                 sys_battery_percent; battery_precheck; echo "rc=$?"'
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "100" ]
    [ "${lines[-1]}" = "rc=0" ]
    [ ! -e "$HOME/pwned-bat" ]
    echo 'garbage text' >"$HOME/ps/BAT0/capacity"
    run sys_lib 'source "$LIB/load.sh" preflight; SYS_POWER_DIR=$HOME/ps; ARG_YES=1; battery_precheck; echo "rc=$?"'
    [ "$status" -eq 0 ]
    [ "$output" = "rc=0" ]
}

@test "env seams: SYS_POWER_DIR and REBOOT_REQUIRED_FILE from the environment are ignored" {
    touch "$HOME/rr"
    run env SYS_POWER_DIR="$HOME/ps" REBOOT_REQUIRED_FILE="$HOME/rr" \
        bash -c 'source "$LIB/load.sh" sys preflight reboot; echo "$SYS_POWER_DIR"; echo "$REBOOT_REQUIRED_FILE"'
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "/sys/class/power_supply" ]
    [ "${lines[1]}" = "/var/run/reboot-required" ]
}

@test "rpi: board state decides the line, the warning, the log and the exit status" {
    local throttled temp abort code power want unwanted
    while IFS='|' read -r throttled temp abort code power want unwanted; do
        stub_vcgencmd "$throttled" "$temp"
        run lib "PATH=$STUBS:\$PATH; RPI_MODEL_FILE=$HOME/model; ARG_YES=1; RPI_ABORT_ON_UNDERVOLTAGE=$abort; rpi_health_check"
        [ "$status" -eq "$code" ]
        [[ "$output" == *"Raspberry Pi 5"*"$temp°C"* ]]
        [[ "$output" == *"$power"* ]]
        [[ "$output" == *$want* ]]
        [[ "$output" != *$unwanted* ]]
        grep -q "rpi: throttled=$throttled temp=$temp" "$HOME/.local/state/emerger/log"
    done <<'ROWS'
0x0|51.2|0|0|power ok|51.2°C*power ok|under-voltage
0x50005|55.0|0|0|UNDER-VOLTAGE|under-voltage right now|Aborting
0x50005|55.0|1|1|UNDER-VOLTAGE|Aborting (RPI_ABORT_ON_UNDERVOLTAGE=1)|Update anyway
0x0|84.5|0|0|power ok|SoC is hot (84.5°C)|under-voltage
ROWS
}

@test "rpi: nothing happens on other boards" {
    stub_vcgencmd 0x1 90.0
    echo "Some Other Board" >"$HOME/model"
    run lib "PATH=$STUBS:\$PATH; RPI_MODEL_FILE=$HOME/model; rpi_health_check"
    [ "$status" -eq 0 ]
    [ -z "$output" ]
}

@test "disk_free_mb: prints the free MiB, empty with exit 0 when df fails under pipefail" {
    stub df 'echo "Filesystem Blocks Used Available Capacity Mounted"; echo "/dev/x 9 1 7 50% /"'
    run sys_lib 'source "$LIB/load.sh" preflight; disk_free_mb /'
    [ "$status" -eq 0 ]
    [ "$output" = "7" ]
    stub df 'exit 1'
    run sys_lib 'source "$LIB/load.sh" preflight; set -eo pipefail; v=$(disk_free_mb /); echo "[$v] rc=$?"; disk_precheck; echo after'
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "[] rc=0" ]
    [ "${lines[1]}" = "after" ]
}
