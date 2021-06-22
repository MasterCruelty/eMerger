#!/bin/bash

source $(dirname "$(readlink -f "$0")")/utils/global.sh

PKG="apt-get"

if [[ $(command -v apt) ]]; then
	PKG="apt"
fi

printf "${GREEN}\nPackage manager detected: ${RED}Using $PKG${NORMAL}"


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

printf "\n"
