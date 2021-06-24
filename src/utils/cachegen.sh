#!/bin/bash

### generates default caches ###
OUT=""

OUT+="utils/privileges\n"

# arch
if [[ $(command -v pacman) ]]; then
    OUT+="package/archlinux\n"
fi

# debian
if [[ $(command -v apt-get) ]]; then
    OUT+="package/debian\n"
fi

# flatpak
if [[ $(command -v flatpak) ]]; then
    OUT+="package/flatpak\n"
fi

# gentoo
if [[ $(command -v emerge) ]]; then
    OUT+="package/gentoo\n"
fi

# opensuse
if [[ $(command -v zypper) ]]; then
    OUT+="package/opensuse\n"
fi

# rpm
if [[ $(command -v yum) ]]; then
    OUT+="package/rpm\n"
fi

# snap
if [[ $(command -v snap) ]]; then
    OUT+="package/snap\n"
fi

# termux
if [[ $(command -v pkg) ]]; then
    OUT+="package/termux\n"
fi

OUT+="utils/trash"

echo -e "$OUT"