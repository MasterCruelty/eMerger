#!/bin/bash

### generates default caches ###
OUT="$(pwd | awk -F 'Updater/src/utils' '{print $1}')\n"

# array that contain all package manager
declare -A pkg
pkg=(
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

# I check for every package which one is available on the system.
for i in ${!pkg[@]}; do
    if [[ $(command -v $i) ]]; then
        OUT+="package/${pkg[$i]}\n"
    fi
done

OUT+="utils/trash"

echo -e "$OUT"
