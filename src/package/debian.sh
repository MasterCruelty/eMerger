#!/bin/bash

src_path=$(dirname "$(readlink -f "$0")")
source "$src_path"/other/global.sh

PKG="apt-get"

if [[ $(command -v apt) ]]; then
	PKG="apt"
fi

printf "${GREEN}System detected: ${RED}Using $PKG\n${NORMAL}"


printProgress "update: starting"
sudo $PKG update
printProgress "update: completed"

printProgress "upgrade: starting"
sudo $PKG upgrade
printProgress "upgrade: completed"

printProgress "autoclean: starting"
sudo $PKG autoclean
printProgress "autoclean: completed"

printProgress "autoremove: starting"
sudo $PKG autoremove
printProgress "autoremove: completed"
