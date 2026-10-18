#!/usr/bin/env bash
# Package manager detection, cached in $EMERGER_CACHE/detected for speed.

# Cache TTL in seconds for the per-manager detection cache.
# Override with EMERGER_CACHE_TTL (0 disables caching).
: "${EMERGER_CACHE_TTL:=86400}"

# Return 0 if manager $1 is installed, probed now without the cache.
# Unknown names return 1.
_pkg_detect_raw() {
    case "$1" in
        pacman)  sys_has pacman ;;
        apt)     sys_has apt || sys_has apt-get ;;
        dnf)     sys_has dnf ;;
        yum)     sys_has yum && ! sys_has dnf ;;
        zypper)  sys_has zypper ;;
        xbps)    sys_has xbps-install ;;
        apk)     sys_has apk ;;
        eopkg)   sys_has eopkg ;;
        emerge)  sys_has emerge ;;
        nix)     sys_has nixos-rebuild || sys_has nix-env ;;
        brew)    sys_has brew ;;
        mas)     sys_has mas ;;
        softwareupdate)
                 [[ $(uname -s) == Darwin ]] && sys_has softwareupdate ;;
        flatpak) sys_has flatpak ;;
        snap)    sys_has snap ;;
        yay)     sys_has yay ;;
        paru)    sys_has paru ;;
        fwupd)   sys_has fwupdmgr ;;
        rpi-eeprom) sys_has rpi-eeprom-update && rpi_has_eeprom ;;
        rustup)  sys_has rustup ;;
        cargo)   sys_has cargo && cargo install-update --version >/dev/null 2>&1 ;;
        npm)     sys_has npm ;;
        pnpm)    sys_has pnpm ;;
        pip)     sys_has pip || sys_has pip3 ;;
        gem)     sys_has gem ;;
        *) return 1 ;;
    esac
}

# Return 0 if the detection cache $1 is younger than EMERGER_CACHE_TTL.
_pkg_is_cache_fresh() {
    local cache="$1"
    (( EMERGER_CACHE_TTL <= 0 )) && return 1
    [[ -f $cache ]] || return 1
    local now mtime age
    now=$(date +%s)
    mtime=$(stat -c %Y "$cache" 2>/dev/null || stat -f %m "$cache" 2>/dev/null || echo 0)
    age=$(( now - mtime ))
    (( age < EMERGER_CACHE_TTL ))
}

# Return 0 if manager $1 is installed. Results are cached one line per
# manager in $EMERGER_CACHE/detected ("name" or "!name"). A stale cache is
# emptied as a whole, by rename so a reader never sees a half-written file,
# and every manager is probed again.
pkg_detect() {
    local manager="$1" cache="${EMERGER_CACHE:-}/detected" line
    if _pkg_is_cache_fresh "$cache"; then
        while IFS= read -r line; do
            [[ $line == "$manager" ]] && return 0
            [[ $line == "!$manager" ]] && return 1
        done <"$cache"
    elif [[ -n ${EMERGER_CACHE:-} && -f $cache ]]; then
        : >"$cache.tmp.$$" 2>/dev/null && mv -f "$cache.tmp.$$" "$cache" 2>/dev/null
        rm -f "$cache.tmp.$$" 2>/dev/null
    fi
    local rc
    if declare -F plugin_is >/dev/null && plugin_is "$manager"; then
        plugin_detect "$manager"; rc=$?
    else
        _pkg_detect_raw "$manager"; rc=$?
    fi
    local entry="$manager"
    (( rc == 0 )) || entry="!$manager"
    if [[ -n ${EMERGER_CACHE:-} ]] && (( EMERGER_CACHE_TTL > 0 )); then
        printf '%s\n' "$entry" >>"$cache" 2>/dev/null || true
    fi
    (( rc == 0 ))
}
