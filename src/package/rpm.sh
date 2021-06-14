#!/bin/bash

src_path="$(dirname "$(readlink -f "$0")")"
source "$src_path"/other/global.sh

PKG="yum"

if [[ -n "$(command -v dnf)" ]]; then
	PKG="dnf"
fi

printf "${GREEN}System detected: ${RED}Using $PKG\n${NORMAL}"

printProgress "update: starting"
sudo $PKG update
printProgress "update: completed"

printProgress "upgrade: starting"
sudo $PKG upgrade
printProgress "upgrade: completed"

printProgress "autoremove: starting"
sudo $PKG autoremove
printProgress "autoremove: completed"

printProgress "clean all: starting"
sudo $PKG clean all
printProgress "clean all: completed"
