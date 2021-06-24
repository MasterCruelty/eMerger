#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/checkpwr.sh)
PKG="emerge"

printf "${GREEN}\nPackage manager detected: ${RED}Using $PKG${NORMAL}\n"

printProgress "syncing: starting"
$PWR $PKG --sync
printProgress "syncing: completed"

printProgress "update: starting"
$PWR $PKG --update --deep --newuse --with-bdeps y @world --ask
printProgress "update: completed"

printProgress "deepclean: starting"
$PWR $PKG --depclean --ask
revdep-rebuild
printProgress "deepclean: completed"

printf "\n"
