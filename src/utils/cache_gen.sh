#!/bin/bash

### generates default caches ###

# path
OUT="$(pwd | awk -F 'eMerger/src/utils' '{print $1}')\n"

# check for first available terminal
declare -a TERMINAL
TERMINAL=(
    "xfce4-terminal"
    "xterm"
    "konsole"
    "terminator"
    "lxterminal"
    "gnome-terminal"
)

# this flag goes to 1 if we have a known terminal
FLAG=0
for i in ${TERMINAL[@]}; do
    if [[ $(command -v $i) ]]; then
        OUT+="$i\n"
        FLAG=1
        break
    fi
done

if [[ $FLAG -eq 0 ]]; then
    OUT+="unknown\n"
fi

# package managers dictionary
declare -A PKG
PKG=(
    ["pacman"]="arch"
    ["apt-get"]="debian"
    ["flatpak"]="flatpak"
    ["emerge"]="gentoo"
    ["nixos-rebuild"]="nix"
    ["zypper"]="opensuse"
    ["rpm"]="rpm"
    ["snap"]="snap"
    ["pkg"]="termux"
)

# check for privileges
if [[ $(command -v pkg) ]]; then
    :
else
    OUT+="utils/privileges\n"
fi

# check for available package manager
for i in ${!PKG[@]}; do
    if [[ $(command -v $i) ]]; then
        OUT+="package/${PKG[$i]}\n"
    fi
done

OUT+="utils/cache\n"
OUT+="utils/trash"

echo -e "$OUT"
