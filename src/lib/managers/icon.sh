#!/usr/bin/env bash
# Package manager icons for the section headers.

# Print the section icon of manager $1: an emoji with an emoji font, a
# plain Unicode symbol without one, a bullet in ASCII mode.
pkg_icon() {
    if (( UI_HAS_EMOJI )); then
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
            mas)            printf '\xf0\x9f\x9b\x8d' ;;
            softwareupdate) printf '\xf0\x9f\x92\xbb' ;;
            flatpak)        printf '\xf0\x9f\x93\xa6' ;;
            snap)           printf '\xf0\x9f\x90\xa2' ;;
            eopkg)          printf '\xf0\x9f\xa7\xb1' ;;
            fwupd)          printf '\xf0\x9f\x94\xa7' ;;
            rpi-eeprom)     printf '\xf0\x9f\x8d\x93' ;;
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
    elif (( UI_HAS_UNICODE )); then
        # No emoji font: plain symbols any font has.
        case "$1" in
            flatpak|snap|brew|mas)         printf '\xe2\x96\xa3' ;;
            nix)                           printf '\xe2\x9d\x84' ;;
            fwupd|rpi-eeprom)              printf '\xe2\x9a\x99' ;;
            rustup|cargo|npm|pnpm|pip|gem) printf '\xce\xbb' ;;
            *)                             printf '\xe2\x97\x86' ;;
        esac
    else
        printf '%s' "$(ui_glyph bullet)"
    fi
}
