#!/usr/bin/env bash
# Package manager registry and dispatcher.
# Detection is cached in $EMERGER_CACHE/detected for speed.

PKG_MANAGERS=(
    pacman yay paru
    apt dnf yum zypper xbps apk eopkg emerge nix
    softwareupdate brew mas
    fwupd
    flatpak snap
    rustup cargo npm pnpm pip gem
)

pkg_needs_sudo() {
    case "$1" in
        pacman|apt|dnf|yum|zypper|xbps|apk|eopkg|emerge|fwupd|snap|softwareupdate) return 0 ;;
        nix) sys_has nixos-rebuild ;;
        *)
            if declare -F plugin_is >/dev/null && plugin_is "$1"; then
                plugin_needs_sudo "$1"
            else
                return 1
            fi
            ;;
    esac
}

pkg_is_dev() {
    case "$1" in
        rustup|cargo|npm|pnpm|pip|gem) return 0 ;;
        *)
            if declare -F plugin_is >/dev/null && plugin_is "$1"; then
                plugin_is_dev "$1"
            else
                return 1
            fi
            ;;
    esac
}

pkg_is_parallelizable() {
    case "$1" in
        flatpak|snap|brew|mas|rustup|cargo|npm|pnpm|pip|gem) return 0 ;;
        *)
            if declare -F plugin_is >/dev/null && plugin_is "$1"; then
                plugin_is_parallel "$1"
            else
                return 1
            fi
            ;;
    esac
}

# Cache TTL in seconds for the per-manager detection cache.
# Override with EMERGER_CACHE_TTL (0 disables caching).
: "${EMERGER_CACHE_TTL:=86400}"

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
        rustup)  sys_has rustup ;;
        cargo)   sys_has cargo && cargo install-update --version >/dev/null 2>&1 ;;
        npm)     sys_has npm ;;
        pnpm)    sys_has pnpm ;;
        pip)     sys_has pip || sys_has pip3 ;;
        gem)     sys_has gem ;;
        *) return 1 ;;
    esac
}

_pkg_cache_fresh() {
    local cache="$1"
    (( EMERGER_CACHE_TTL <= 0 )) && return 1
    [[ -f $cache ]] || return 1
    local now mtime age
    now=$(date +%s)
    mtime=$(stat -c %Y "$cache" 2>/dev/null || stat -f %m "$cache" 2>/dev/null || echo 0)
    age=$(( now - mtime ))
    (( age < EMERGER_CACHE_TTL ))
}

pkg_detect() {
    local m="$1" cache="${EMERGER_CACHE:-}/detected"
    if _pkg_cache_fresh "$cache"; then
        grep -q "^$m\$" "$cache" && return 0
        grep -q "^!$m\$" "$cache" && return 1
    fi
    local rc
    if declare -F plugin_is >/dev/null && plugin_is "$m"; then
        plugin_detect "$m"; rc=$?
    else
        _pkg_detect_raw "$m"; rc=$?
    fi
    if (( rc == 0 )); then
        [[ -n ${EMERGER_CACHE:-} ]] && printf '%s\n' "$m" >>"$cache" 2>/dev/null
        return 0
    else
        [[ -n ${EMERGER_CACHE:-} ]] && printf '!%s\n' "$m" >>"$cache" 2>/dev/null
        return 1
    fi
}

pkg_icon() {
    if (( UI_UNICODE )); then
        case "$1" in
            pacman|yay|paru) printf '\xf0\x9f\x8f\xb9' ;;
            apt)            printf '\xf0\x9f\x8c\x80' ;;
            dnf|yum)        printf '\xf0\x9f\xa4\xa0' ;;
            zypper)         printf '\xf0\x9f\xa6\x8e' ;;
            apk)            printf '\xe2\x9b\xb0' ;;
            xbps)           printf '\xf0\x9f\x95\xb3' ;;
            emerge)         printf '\xf0\x9f\x90\xa7' ;;
            nix)            printf '\xe2\x9d\x84' ;;
            brew)           printf '\xf0\x9f\x8d\xba' ;;
            mas)            printf '\xef\xa3\xbf' ;;
            softwareupdate) printf '\xef\xa3\xbf' ;;
            flatpak)        printf '\xf0\x9f\x93\xa6' ;;
            snap)           printf '\xf0\x9f\x90\xa2' ;;
            eopkg)          printf '\xf0\x9f\xa7\xb1' ;;
            fwupd)          printf '\xf0\x9f\x94\xa7' ;;
            rustup|cargo)   printf '\xf0\x9f\xa6\x80' ;;
            npm|pnpm)       printf '\xf0\x9f\x93\x97' ;;
            pip)            printf '\xf0\x9f\x90\x8d' ;;
            gem)            printf '\xf0\x9f\x92\x8e' ;;
            *)
                if declare -F plugin_is >/dev/null && plugin_is "$1"; then
                    plugin_icon "$1"
                else
                    printf '%s' "$(ui_glyph bullet)"
                fi
                ;;
        esac
    else
        printf '%s' "$(ui_glyph bullet)"
    fi
}

pkg_run() {
    local mgr="$1" sudo_cmd="" rc=0
    _PKG_CURRENT="$mgr"
    if pkg_needs_sudo "$mgr"; then sudo_cmd="sudo"; fi

    local ic est
    ic=$(pkg_icon "$mgr")
    est=$(estimate_for "$mgr")
    ui_title "$ic $mgr${est:+  $est}"
    log_info "starting $mgr"

    # Route to plugin if registered.
    if declare -F plugin_is >/dev/null && plugin_is "$mgr"; then
        plugin_run "$mgr"; rc=$?
        _PKG_CURRENT=""
        (( rc == 0 )) && log_info "$mgr: ok" || log_error "$mgr: rc=$rc"
        return $rc
    fi

    # Pacman can natively honor an ignore list.
    local pacman_ignore=""
    sys_has pacman && pacman_ignore=$(ignore_pacman_flag)

    case "$mgr" in
        pacman)
            # shellcheck disable=SC2086
            run_cmd "refresh databases" $sudo_cmd pacman -Syy --noconfirm $pacman_ignore || rc=$?
            if (( ARG_DOWNLOAD_ONLY )); then
                # shellcheck disable=SC2086
                run_cmd "download only" $sudo_cmd pacman -Syuw --noconfirm $pacman_ignore || rc=$?
            else
                # shellcheck disable=SC2086
                run_cmd "upgrade system" $sudo_cmd pacman -Syu --noconfirm $pacman_ignore || rc=$?
                if sys_has paccache; then
                    run_cmd "clean package cache" $sudo_cmd paccache -rk2 || true
                fi
            fi
            ;;
        apt)
            local apt_bin=apt-get
            sys_has apt && apt_bin=apt
            run_cmd "fix broken"  $sudo_cmd "$apt_bin" --fix-broken install -y || rc=$?
            run_cmd "update"      $sudo_cmd "$apt_bin" update || rc=$?
            if (( ARG_DOWNLOAD_ONLY )); then
                local upflag=full-upgrade
                [[ $apt_bin == apt-get ]] && upflag=dist-upgrade
                run_cmd "$upflag --download-only" $sudo_cmd "$apt_bin" "$upflag" -y --download-only || rc=$?
            else
                if (( ARG_SECURITY )) && sys_has unattended-upgrade; then
                    run_cmd "security upgrade" $sudo_cmd unattended-upgrade -v || rc=$?
                else
                    local upflag=full-upgrade
                    [[ $apt_bin == apt-get ]] && upflag=dist-upgrade
                    run_cmd "$upflag"  $sudo_cmd "$apt_bin" "$upflag" -y || rc=$?
                fi
                run_cmd "autoremove"  $sudo_cmd "$apt_bin" autoremove -y || rc=$?
                run_cmd "autoclean"   $sudo_cmd "$apt_bin" autoclean -y || rc=$?
                run_cmd "clean"       $sudo_cmd "$apt_bin" clean || rc=$?
            fi
            ;;
        dnf)
            local sec=""
            (( ARG_SECURITY )) && sec="--security"
            if (( ARG_DOWNLOAD_ONLY )); then
                run_cmd "download only" $sudo_cmd dnf upgrade -y --downloadonly $sec || rc=$?
            else
                run_cmd "upgrade"     $sudo_cmd dnf upgrade -y $sec || rc=$?
                run_cmd "autoremove"  $sudo_cmd dnf autoremove -y || rc=$?
                run_cmd "clean all"   $sudo_cmd dnf clean all || rc=$?
            fi
            ;;
        yum)
            run_cmd "update"      $sudo_cmd yum update -y || rc=$?
            run_cmd "clean all"   $sudo_cmd yum clean all || rc=$?
            ;;
        zypper)
            run_cmd "refresh"     $sudo_cmd zypper --non-interactive refresh || rc=$?
            if (( ARG_DOWNLOAD_ONLY )); then
                run_cmd "download only" $sudo_cmd zypper --non-interactive update --download-only || rc=$?
            elif (( ARG_SECURITY )); then
                run_cmd "security patch" $sudo_cmd zypper --non-interactive patch --category security || rc=$?
            else
                run_cmd "update"  $sudo_cmd zypper --non-interactive update || rc=$?
            fi
            run_cmd "clean"       $sudo_cmd zypper clean || true
            ;;
        xbps)
            run_cmd "sync & upgrade" $sudo_cmd xbps-install -Suy || rc=$?
            run_cmd "remove orphans" $sudo_cmd xbps-remove -Oy || true
            ;;
        apk)
            run_cmd "update"      $sudo_cmd apk update || rc=$?
            run_cmd "upgrade"     $sudo_cmd apk upgrade || rc=$?
            run_cmd "clean cache" $sudo_cmd apk cache clean || true
            ;;
        eopkg)
            run_cmd "upgrade"     $sudo_cmd eopkg upgrade -y || rc=$?
            run_cmd "delete cache" $sudo_cmd eopkg delete-cache || true
            ;;
        emerge)
            run_cmd "sync"        $sudo_cmd emerge --sync --quiet || rc=$?
            run_cmd "update world" $sudo_cmd emerge -uDN --quiet @world || rc=$?
            run_cmd "depclean"    $sudo_cmd emerge --depclean --quiet || true
            ;;
        nix)
            if sys_has nixos-rebuild; then
                run_cmd "nixos-rebuild switch --upgrade" $sudo_cmd nixos-rebuild switch --upgrade || rc=$?
                run_cmd "collect garbage" $sudo_cmd nix-collect-garbage -d || true
            else
                run_cmd "channel update" nix-channel --update || rc=$?
                run_cmd "upgrade"        nix-env -u || rc=$?
                run_cmd "collect garbage" nix-collect-garbage -d || true
            fi
            ;;
        brew)
            run_cmd "update"      brew update || rc=$?
            run_cmd "upgrade"     brew upgrade || rc=$?
            run_cmd "upgrade casks" brew upgrade --cask || true
            run_cmd "cleanup"     brew cleanup -s || true
            ;;
        mas)
            run_cmd "mas upgrade" mas upgrade || rc=$?
            ;;
        softwareupdate)
            if (( ARG_SECURITY )); then
                run_cmd "install recommended" $sudo_cmd softwareupdate --install --recommended --agree-to-license || rc=$?
            else
                run_cmd "list" softwareupdate --list || true
                run_cmd "install all" $sudo_cmd softwareupdate --install --all --agree-to-license --no-scan || rc=$?
            fi
            ;;
        flatpak)
            run_cmd "update"          flatpak update -y --noninteractive || rc=$?
            run_cmd "uninstall unused" flatpak uninstall --unused -y --noninteractive || true
            ;;
        snap)
            run_cmd "refresh"     $sudo_cmd snap refresh || rc=$?
            ;;
        yay)
            # shellcheck disable=SC2086
            run_cmd "AUR upgrade" yay -Syu --noconfirm $pacman_ignore || rc=$?
            ;;
        paru)
            # shellcheck disable=SC2086
            run_cmd "AUR upgrade" paru -Syu --noconfirm $pacman_ignore || rc=$?
            ;;
        fwupd)
            run_cmd "refresh metadata" $sudo_cmd fwupdmgr refresh --force || rc=$?
            run_cmd "firmware update"  $sudo_cmd fwupdmgr update -y --no-reboot-check || true
            ;;
        rustup)
            run_cmd "rustup update" rustup update || rc=$?
            ;;
        cargo)
            run_cmd "cargo install-update" cargo install-update -a || rc=$?
            ;;
        npm)
            run_cmd "npm update -g" npm update -g || rc=$?
            ;;
        pnpm)
            run_cmd "pnpm -g update" pnpm -g update || rc=$?
            ;;
        pip)
            local pip_bin=pip
            sys_has pip3 && pip_bin=pip3
            local flags="--user"
            sys_is_root && flags=""
            run_cmd "pip upgrade" bash -c "$pip_bin list --outdated --format=freeze $flags 2>/dev/null | cut -d= -f1 | xargs -r $pip_bin install -U $flags" || rc=$?
            ;;
        gem)
            run_cmd "gem update"  gem update || rc=$?
            ;;
    esac

    _PKG_CURRENT=""
    if (( rc == 0 )); then
        log_info "$mgr: ok"
    else
        log_error "$mgr: rc=$rc"
    fi
    return $rc
}
