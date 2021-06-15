#!/bin/bash

src_path=$(dirname "$(readlink -f "$0")")
source "$src_path"/utils/global.sh

PKG="pacman"

printf "${GREEN}\nSystem detected: ${RED}Using $PKG\n${NORMAL}"

printProgress "update: starting"
sudo $PKG -Syy
printProgress "update: completed"

printProgress "upgrade: starting"
sudo $PKG -Syu
printProgress "upgrade: completed"

printProgress "clean all: starting"
sudo $PKG -R $($PKG -Qtdq)
printProgress "clean all: completed"
