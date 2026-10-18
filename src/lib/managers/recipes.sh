#!/usr/bin/env bash
# Package manager dispatcher: the commands each manager runs.

# Update manager $1: print its section, then run its plugin or its recipe
# with the privilege prefix it needs. Return the last failing step's code, 0 when all pass.
pkg_run() {
    local manager="$1" sudo_cmd="" rc=0
    _PKG_CURRENT="$manager"
    # Root runs managers directly: a container or CI image may have no sudo.
    if pkg_needs_sudo "$manager"; then sudo_cmd=$(sys_sudo_prefix); fi

    local icon estimate
    icon=$(pkg_icon "$manager")
    estimate=$(estimate_for "$manager")
    ui_section "$icon" "$manager" "$estimate"
    log_info "starting $manager"

    if (( ${ARG_DOWNLOAD_ONLY:-0} )) && ! pkg_has_download_only "$manager"; then
        ui_warn "skip $manager: no download-only mode, --download-only never installs"
        log_warn "$manager skipped: no download-only mode"
        _PKG_CURRENT=""
        return 0
    fi

    if declare -F plugin_is >/dev/null && plugin_is "$manager"; then
        plugin_run "$manager"; rc=$?
        _PKG_CURRENT=""
        (( rc == 0 )) && log_info "$manager: ok" || log_error "$manager: rc=$rc"
        return $rc
    fi

    # Pacman can natively honor an ignore list.
    local pacman_ignore=""
    sys_has pacman && pacman_ignore=$(ignore_pacman_flag)

    case "$manager" in
        pacman) _pkg_run_pacman ;;
        apt) _pkg_run_apt ;;
        dnf) _pkg_run_dnf ;;
        yum) _pkg_run_yum ;;
        zypper) _pkg_run_zypper ;;
        xbps) _pkg_run_xbps ;;
        apk) _pkg_run_apk ;;
        eopkg) _pkg_run_eopkg ;;
        emerge) _pkg_run_emerge ;;
        nix) _pkg_run_nix ;;
        brew) _pkg_run_brew ;;
        mas) _pkg_run_mas ;;
        softwareupdate) _pkg_run_softwareupdate ;;
        flatpak) _pkg_run_flatpak ;;
        snap) _pkg_run_snap ;;
        yay) _pkg_run_yay ;;
        paru) _pkg_run_paru ;;
        fwupd) _pkg_run_fwupd ;;
        rpi-eeprom) _pkg_run_rpi_eeprom ;;
        rustup) _pkg_run_rustup ;;
        cargo) _pkg_run_cargo ;;
        npm) _pkg_run_npm ;;
        pnpm) _pkg_run_pnpm ;;
        pip) _pkg_run_pip ;;
        gem) _pkg_run_gem ;;
    esac

    _PKG_CURRENT=""
    if (( rc == 0 )); then
        log_info "$manager: ok"
    else
        log_error "$manager: rc=$rc"
    fi
    return $rc
}

# Recipes, one per manager, called by pkg_run only: each reads its locals
# sudo_cmd (privilege prefix) and pacman_ignore, and sets its rc on failure.

# Run pacman: refresh, then upgrade (or download only) and trim the package cache.
_pkg_run_pacman() {
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
}

# Run apt: repair, update, then upgrade (security or download only on request), autoremove and clean.
_pkg_run_apt() {
    local apt_bin=apt-get
    sys_has apt && apt_bin=apt
    # Status-Fd lines feed the progress bar, useless with -v.
    local -a apt_options=()
    (( UI_VERBOSE )) || apt_options=(-o APT::Status-Fd=1)
    # Under --download-only the repair only fetches what it would install.
    local -a fix_options=()
    (( ARG_DOWNLOAD_ONLY )) && fix_options=(--download-only)
    run_cmd "fix broken"  $sudo_cmd "$apt_bin" "${apt_options[@]}" --fix-broken install -y "${fix_options[@]}" || rc=$?
    run_cmd "update"      $sudo_cmd "$apt_bin" "${apt_options[@]}" update || rc=$?
    if (( ARG_DOWNLOAD_ONLY )) && (( ARG_SECURITY )); then
        run_cmd "security download only" $sudo_cmd unattended-upgrade -v --download-only || rc=$?
    elif (( ARG_DOWNLOAD_ONLY )); then
        local upgrade_command=full-upgrade
        [[ $apt_bin == apt-get ]] && upgrade_command=dist-upgrade
        run_cmd "$upgrade_command --download-only" $sudo_cmd "$apt_bin" "${apt_options[@]}" "$upgrade_command" -y --download-only || rc=$?
    else
        if (( ARG_SECURITY )); then
            run_cmd "security upgrade" $sudo_cmd unattended-upgrade -v || rc=$?
        else
            local upgrade_command=full-upgrade
            [[ $apt_bin == apt-get ]] && upgrade_command=dist-upgrade
            run_cmd "$upgrade_command"  $sudo_cmd "$apt_bin" "${apt_options[@]}" "$upgrade_command" -y || rc=$?
        fi
        run_cmd "autoremove"  $sudo_cmd "$apt_bin" "${apt_options[@]}" autoremove -y || rc=$?
        run_cmd "autoclean"   $sudo_cmd "$apt_bin" autoclean -y || rc=$?
        run_cmd "clean"       $sudo_cmd "$apt_bin" clean || rc=$?
    fi
}

# Run dnf: upgrade (security or download only on request), autoremove and clean.
_pkg_run_dnf() {
    local security_flag=""
    (( ARG_SECURITY )) && security_flag="--security"
    if (( ARG_DOWNLOAD_ONLY )); then
        run_cmd "download only" $sudo_cmd dnf upgrade -y --downloadonly $security_flag || rc=$?
    else
        run_cmd "upgrade"     $sudo_cmd dnf upgrade -y $security_flag || rc=$?
        run_cmd "autoremove"  $sudo_cmd dnf autoremove -y || rc=$?
        run_cmd "clean all"   $sudo_cmd dnf clean all || rc=$?
    fi
}

# Run yum: update (security only on request) and clean.
_pkg_run_yum() {
    local security_flag=""
    (( ARG_SECURITY )) && security_flag="--security"
    run_cmd "update"      $sudo_cmd yum update -y $security_flag || rc=$?
    run_cmd "clean all"   $sudo_cmd yum clean all || rc=$?
}

# Run zypper: refresh, then update or patch (security or download only on request) and clean.
_pkg_run_zypper() {
    run_cmd "refresh"     $sudo_cmd zypper --non-interactive refresh || rc=$?
    if (( ARG_DOWNLOAD_ONLY )) && (( ARG_SECURITY )); then
        run_cmd "security download only" $sudo_cmd zypper --non-interactive patch --category security --download-only || rc=$?
    elif (( ARG_DOWNLOAD_ONLY )); then
        run_cmd "download only" $sudo_cmd zypper --non-interactive update --download-only || rc=$?
    elif (( ARG_SECURITY )); then
        run_cmd "security patch" $sudo_cmd zypper --non-interactive patch --category security || rc=$?
    else
        run_cmd "update"  $sudo_cmd zypper --non-interactive update || rc=$?
    fi
    # zypper clean would delete what --download-only just fetched.
    (( ARG_DOWNLOAD_ONLY )) || run_cmd "clean" $sudo_cmd zypper clean || true
}

# Run xbps: sync and upgrade, remove orphans.
_pkg_run_xbps() {
    run_cmd "sync & upgrade" $sudo_cmd xbps-install -Suy || rc=$?
    run_cmd "remove orphans" $sudo_cmd xbps-remove -Oy || true
}

# Run apk: update, upgrade, clean the cache.
_pkg_run_apk() {
    run_cmd "update"      $sudo_cmd apk update || rc=$?
    run_cmd "upgrade"     $sudo_cmd apk upgrade || rc=$?
    run_cmd "clean cache" $sudo_cmd apk cache clean || true
}

# Run eopkg: upgrade, delete the cache.
_pkg_run_eopkg() {
    run_cmd "upgrade"     $sudo_cmd eopkg upgrade -y || rc=$?
    run_cmd "delete cache" $sudo_cmd eopkg delete-cache || true
}

# Run emerge: sync, update @world, depclean.
_pkg_run_emerge() {
    run_cmd "sync"        $sudo_cmd emerge --sync --quiet || rc=$?
    run_cmd "update world" $sudo_cmd emerge -uDN --quiet @world || rc=$?
    run_cmd "depclean"    $sudo_cmd emerge --depclean --quiet || true
}

# Run nix: NixOS rebuild or channel update and upgrade, then collect garbage.
_pkg_run_nix() {
    if sys_has nixos-rebuild; then
        run_cmd "nixos-rebuild switch --upgrade" $sudo_cmd nixos-rebuild switch --upgrade || rc=$?
        run_cmd "collect garbage" $sudo_cmd nix-collect-garbage -d || true
    else
        run_cmd "channel update" nix-channel --update || rc=$?
        run_cmd "upgrade"        nix-env -u || rc=$?
        run_cmd "collect garbage" nix-collect-garbage -d || true
    fi
}

# Run brew: update, upgrade formulae and casks, cleanup.
_pkg_run_brew() {
    run_cmd "update"      brew update || rc=$?
    run_cmd "upgrade"     brew upgrade || rc=$?
    run_cmd "upgrade casks" brew upgrade --cask || true
    run_cmd "cleanup"     brew cleanup -s || true
}

# Run mas: upgrade App Store apps.
_pkg_run_mas() {
    run_cmd "mas upgrade" mas upgrade || rc=$?
}

# Run softwareupdate: list, download or install macOS updates, licences agreed only with --accept-licenses.
_pkg_run_softwareupdate() {
    # Installing can mean agreeing to Apple's licence: only on request.
    # Downloading agrees to nothing.
    if (( ARG_DOWNLOAD_ONLY )) && (( ARG_SECURITY )); then
        run_cmd "download recommended" $sudo_cmd softwareupdate --download --recommended || rc=$?
    elif (( ARG_DOWNLOAD_ONLY )); then
        run_cmd "download all" $sudo_cmd softwareupdate --download --all || rc=$?
    elif (( ! ARG_ACCEPT_LICENSES )); then
        run_cmd "list" softwareupdate --list || true
        ui_muted "updates not installed: they may need licence agreement, run with --accept-licenses"
    elif (( ARG_SECURITY )); then
        run_cmd "install recommended" $sudo_cmd softwareupdate --install --recommended --agree-to-license || rc=$?
    else
        run_cmd "list" softwareupdate --list || true
        run_cmd "install all" $sudo_cmd softwareupdate --install --all --agree-to-license --no-scan || rc=$?
    fi
}

# Run flatpak: update, uninstall unused runtimes.
_pkg_run_flatpak() {
    run_cmd "update"          flatpak update -y --noninteractive || rc=$?
    run_cmd "uninstall unused" flatpak uninstall --unused -y --noninteractive || true
}

# Run snap: refresh.
_pkg_run_snap() {
    run_cmd "refresh"     $sudo_cmd snap refresh || rc=$?
}

# Run yay: AUR upgrade.
_pkg_run_yay() {
    # shellcheck disable=SC2086
    run_cmd "AUR upgrade" yay -Syu --noconfirm $pacman_ignore || rc=$?
}

# Run paru: AUR upgrade.
_pkg_run_paru() {
    # shellcheck disable=SC2086
    run_cmd "AUR upgrade" paru -Syu --noconfirm $pacman_ignore || rc=$?
}

# Run fwupd: refresh metadata, update firmware.
_pkg_run_fwupd() {
    run_cmd "refresh metadata" $sudo_cmd fwupdmgr refresh --force || rc=$?
    run_cmd "firmware update"  $sudo_cmd fwupdmgr update -y --no-reboot-check || true
}

# Run rpi-eeprom: check, and with --firmware stage, the Pi bootloader.
_pkg_run_rpi_eeprom() {
    rpi_eeprom_run "$sudo_cmd" || rc=$?
}

# Run rustup: update toolchains.
_pkg_run_rustup() {
    run_cmd "rustup update" rustup update || rc=$?
}

# Run cargo: update installed crates (cargo-update).
_pkg_run_cargo() {
    run_cmd "cargo install-update" cargo install-update -a || rc=$?
}

# Run npm: update global packages.
_pkg_run_npm() {
    run_cmd "npm update -g" npm update -g || rc=$?
}

# Run pnpm: update global packages.
_pkg_run_pnpm() {
    run_cmd "pnpm -g update" pnpm -g update || rc=$?
}

# Run pip: upgrade outdated packages one at a time, printing [i/N].
_pkg_run_pip() {
    local pip_bin=pip
    sys_has pip3 && pip_bin=pip3
    local flags="--user"
    sys_is_root && flags=""
    # One at a time, printing [i/N] for the progress bar.
    # pip >= 22.3 refuses --outdated with --format=freeze.
    run_cmd "pip upgrade" bash -c '
        pip_bin=$1; shift
        mapfile -t pkgs < <("$pip_bin" list --outdated "$@" 2>/dev/null | awk "NR>2 {print \$1}")
        n=${#pkgs[@]} i=0 rc=0
        for p in "${pkgs[@]}"; do
            i=$((i+1)); echo "[$i/$n] $p"
            "$pip_bin" install -U "$@" "$p" || rc=1
        done
        exit $rc' _ "$pip_bin" $flags || rc=$?
}

# Run gem: update gems.
_pkg_run_gem() {
    run_cmd "gem update"  gem update || rc=$?
}
