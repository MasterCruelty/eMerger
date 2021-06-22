#!/bin/bash

source $(dirname "$(readlink -f "$0")")/utils/global.sh

PKG="emerge"

printf "${GREEN}\nSystem detected: ${RED}Using $PKG${NORMAL}"

printProgress "syncing: starting"
$PKG --sync
printProgress "syncing: completed"

printProgress "update: starting"
$PKG --update --deep --newuse --with-bdeps y @world --ask
printProgress "update: completed"

printProgress "deepclean: starting"
$PKG --depclean --ask
revdep-rebuild
printProgress "deepclean: completed"

printf "\n"
