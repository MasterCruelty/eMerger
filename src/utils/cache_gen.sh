#!/bin/bash

### generates default caches ###
OUT="$(pwd | awk -F 'Updater/src/utils' '{print $1}')\n"

# array that contain all package manager
pkg=("pacman" "apt-get" "flatpak" "emerge" "zypper" "yum" "snap" "pkg")
system=("archlinux" "debian" "flatpak" "gentoo" "opensuse" "rpm" "snap" "termux")

# check for privileges
if [[ $(command -v pkg) ]]; then
    :
else
    OUT+="utils/privileges\n"
fi

# I check for every package which one is available on the system.
for i in "${!pkg[@]}"
do
    if [[ $(command -v ${pkg[i]}) ]]; then
        OUT+="package/${system[i]}\n"
    fi
done

OUT+="utils/trash"

echo -e "$OUT"
