#!/bin/bash

### generates default caches ###
OUT=""

# arch
if [[ $(command -v pacman) ]]; then	
	OUT+="archlinux\n"
fi

# debian
if [[ $(command -v apt-get) ]]; then
	OUT+="debian\n"
fi

# flatpak
if [[ $(command -v flatpak) ]]; then
	OUT+="flatpak\n"
fi

#gentoo
if [[ $(command -v emerge) ]]; then
	OUT+="gentoo\n"
fi

# rpm
if [[ $(command -v yum) ]]; then	
	OUT+="rpm\n"
fi

# snap
if [[ $(command -v snap) ]]; then
	OUT+="snap\n"
fi

# termux
if [[ $(command -v pkg) ]]; then
	OUT+="termux"
fi

echo -e "$OUT"