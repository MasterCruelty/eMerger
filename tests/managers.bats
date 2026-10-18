#!/usr/bin/env bats

load test_helper

setup() {
    setup_env
    setup_minbin
    # Managers the tests rely on, so detection does not depend on the host.
    for m in apt snap; do printf '#!/bin/sh\nexit 0\n' >"$STUBS/$m"; chmod +x "$STUBS/$m"; done
    printf '#!/bin/sh\necho "sudo $*" >>"$HOME/sudo.log"\n' >"$STUBS/sudo"; chmod +x "$STUBS/sudo"
}

teardown() {
    teardown_env
}

# Run a snippet with the package dispatcher sourced, in dry-run.
pkg() {
    lib 'EMERGER_CONFIG=$HOME/.config/emerger
         source "$LIB/load.sh" estimate ignore registry detect icon recipes
         DRY_RUN=1; ARG_SECURITY=0; ARG_DOWNLOAD_ONLY=0; ARG_DEV=0
         '"$1"
}

@test "without a filter both stubbed managers run" {
    run $EMERGER -n -y --json
    [ "$status" -eq 0 ]
    [[ "$output" == *'"apt"'* ]]
    [[ "$output" == *'"snap"'* ]]
}

@test "--only filter restricts managers" {
    run $EMERGER -n -y --json --only apt
    [ "$status" -eq 0 ]
    [[ "$output" == *'"apt"'* ]]
    [[ "$output" != *'"snap"'* ]]
}

@test "--except filter skips managers" {
    run $EMERGER -n -y --json --except snap
    [ "$status" -eq 0 ]
    [[ "$output" == *'"apt"'* ]]
    [[ "$output" != *'"snap"'* ]]
}

@test "registry: a plugin answers sudo, dev and security, an unknown name answers no" {
    plugin px '' 'pm_px_needs_sudo() { return 0; }; pm_px_dev() { return 0; }; pm_px_security() { return 1; }'
    run lib 'plugins_load; for q in pkg_needs_sudo pkg_is_dev pkg_has_security pkg_is_parallelizable; do
                 if $q px; then echo "$q yes"; else echo "$q no"; fi; $q nosuch && echo "$q nosuch"; done; true'
    [ "$status" -eq 0 ]
    [ "$output" = "$(printf '%s\n' 'pkg_needs_sudo yes' 'pkg_is_dev yes' 'pkg_has_security no' 'pkg_is_parallelizable no')" ]
}

@test "detection cache: stale entries are dropped, one line per manager" {
    stub apt 'exit 0'
    printf '!apt\n!pacman\n' >"$HOME/.cache/emerger/detected"
    touch -d '2 days ago' "$HOME/.cache/emerger/detected"
    run sys_lib 'pkg_detect pacman || echo "pacman absent"
                 pkg_detect apt && echo "apt found"
                 pkg_detect apt && echo "apt found"
                 sort "$EMERGER_CACHE/detected" | paste -sd,'
    [ "$status" -eq 0 ]
    [ "${lines[0]}" = "pacman absent" ]
    [ "${lines[1]}" = "apt found" ]
    [ "${lines[2]}" = "apt found" ]
    [ "${lines[3]}" = "!pacman,apt" ]
}

@test "detection cache: fresh entry is trusted, TTL 0 disables it" {
    printf 'pacman\n' >"$HOME/.cache/emerger/detected"
    run sys_lib 'pkg_detect pacman && echo cached'
    [ "$output" = "cached" ]
    run sys_lib 'EMERGER_CACHE_TTL=0; pkg_detect pacman || echo probed'
    [ "$output" = "probed" ]
}

@test "rpi: bootloader update applied only with --firmware" {
    cat >"$STUBS/rpi-eeprom-update" <<'EOF'
#!/bin/sh
[ "$1" = "-a" ] && { echo applied >"$HOME/applied"; exit 0; }
echo "BOOTLOADER: update available"
echo "   CURRENT: Thu May  8 2025 (1746713597)"
echo "    LATEST: Fri Sep 25 2026 (1790351949)"
exit 1
EOF
    chmod +x "$STUBS/rpi-eeprom-update"
    run lib "PATH=$STUBS:\$PATH; DRY_RUN=0; ARG_FIRMWARE=0; rpi_eeprom_run ''"
    [ "$status" -eq 0 ]
    [[ "$output" == *"update available"* ]]
    [[ "$output" == *"up --firmware"* ]]
    [ ! -e "$HOME/applied" ]
    run lib "PATH=$STUBS:\$PATH; DRY_RUN=0; ARG_FIRMWARE=1; rpi_eeprom_run ''; echo pending=\$RPI_EEPROM_IS_PENDING"
    [ -e "$HOME/applied" ]
    [[ "$output" == *"pending=1"* ]]
}

@test "softwareupdate accepts the licence only with --accept-licenses" {
    run pkg 'ARG_ACCEPT_LICENSES=0; pkg_run softwareupdate'
    [ "$status" -eq 0 ]
    [[ "$output" != *"--agree-to-license"* ]]
    [[ "$output" != *"--install"* ]]
    [[ "$output" == *"--accept-licenses"* ]]
    run pkg 'ARG_ACCEPT_LICENSES=1; pkg_run softwareupdate'
    [ "$status" -eq 0 ]
    [[ "$output" == *"softwareupdate --install --all --agree-to-license"* ]]
}
