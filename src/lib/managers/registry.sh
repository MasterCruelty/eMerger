#!/usr/bin/env bash
# Package manager registry: the supported managers and what each can do.

# Read by the modules that loop over managers.
# shellcheck disable=SC2034
PKG_MANAGERS=(
    pacman yay paru
    apt dnf yum zypper xbps apk eopkg emerge nix
    softwareupdate brew mas
    fwupd rpi-eeprom
    flatpak snap
    rustup cargo npm pnpm pip gem
)

# Return 0 if manager $1 runs its commands as root: nix only on NixOS,
# rpi-eeprom only with --firmware.
pkg_needs_sudo() {
    case "$1" in
        pacman|apt|dnf|yum|zypper|xbps|apk|eopkg|emerge|fwupd|snap|softwareupdate) return 0 ;;
        nix) sys_has nixos-rebuild ;;
        rpi-eeprom) (( ${ARG_FIRMWARE:-0} )) ;;
        *) _pkg_plugin_ask plugin_needs_sudo "$1" ;;
    esac
}

# Return 0 if manager $1 updates developer tooling, which runs only with --dev.
pkg_is_dev() {
    case "$1" in
        rustup|cargo|npm|pnpm|pip|gem) return 0 ;;
        *) _pkg_plugin_ask plugin_is_dev "$1" ;;
    esac
}

# Return 0 if manager $1 can install security updates alone, which is what
# --security runs. apt needs unattended-upgrade, a plugin needs
# pm_<slug>_security. Every other manager is skipped under --security.
pkg_has_security() {
    case "$1" in
        dnf|yum|zypper|softwareupdate) return 0 ;;
        apt) sys_has unattended-upgrade ;;
        *) _pkg_plugin_ask plugin_has_security "$1" ;;
    esac
}

# Return 0 if manager $1 has a mode that downloads updates without
# installing them, which is all --download-only runs. Every other manager,
# plugins included, is skipped under --download-only.
pkg_has_download_only() {
    case "$1" in
        pacman|apt|dnf|zypper|softwareupdate) return 0 ;;
        *) return 1 ;;
    esac
}

# Return 0 if manager $1 can run beside others under --parallel.
pkg_is_parallelizable() {
    case "$1" in
        flatpak|snap|brew|mas|rustup|cargo|npm|pnpm|pip|gem) return 0 ;;
        *) _pkg_plugin_ask plugin_is_parallel "$1" ;;
    esac
}

# Run plugin query $1 (plugin_needs_sudo, plugin_is_dev, ...) for manager $2:
# its answer when $2 is a registered plugin, else 1.
_pkg_plugin_ask() {
    if declare -F plugin_is >/dev/null && plugin_is "$2"; then
        "$1" "$2"
    else
        return 1
    fi
}
