#!/bin/bash

### generates default caches ###

# path
OUT="$(pwd | awk -F 'Updater/src/utils' '{print $1}')\n"

# check for first available terminal
# LEAVE IT AS TERMINAL, DO NOT CALL IT TERM
declare -a TERMINAL
TERMINAL=(
    "xterm"
    "konsole"
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
    ["pacman"]="archlinux"
    ["apt-get"]="debian"
    ["flatpak"]="flatpak"
    ["emerge"]="gentoo"
    ["zypper"]="opensuse"
    ["yum"]="rpm"
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

OUT+="utils/trash"

echo -e "$OUT"
