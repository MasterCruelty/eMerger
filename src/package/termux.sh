#!/bin/bash

source $(dirname "$(readlink -f "$0")")/utils/global.sh

PKG="pkg"

printf "${GREEN}\nPackage manager detected: ${RED}Using $PKG${NORMAL}"

printProgress "update: starting"
$PKG update
printProgress "update: completed"

printProgress "upgrade: starting"
$PKG upgrade
printProgress "upgrade: completed"

printProgress "autoclean: starting"
$PKG autoclean
printProgress "autoclean: completed"

printf "\n"