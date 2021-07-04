#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="flatpak"

printf "${BLUE}\nUsing $PKG $FLATPAK${NORMAL}\n"

printProgress "update: starting"
$PWR $PKG update
printProgress "update: completed"

printProgress "repair: starting"
$PWR $PKG repair
printProgress "repair: completed"

printProgress "uninstall unused extensions: starting"
$PWR $PKG uninstall --unused
printProgress "uninstall unused extensions: completed"

printf "\n"
