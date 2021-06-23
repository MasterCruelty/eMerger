#!/bin/bash

source $(dirname "$(readlink -f "$0")")/utils/global.sh

PKG="yum"

if [[ $(command -v dnf) ]]; then
	PKG="dnf"
fi

printf "${GREEN}\nPackage manager detected: ${RED}Using $PKG${NORMAL}"

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

printf "\n"