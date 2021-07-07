#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="nixos-rebuild switch"

printf "${BLUE}\nUsing $PKG $NIX${NORMAL}\n"

printProgress "upgrade: starting"
$PWR $PKG --upgrade
printProgress "upgrade: completed"

printProgress "repair: starting"
$PWR $PKG --repair
printProgress "repair: completed"

printf "\n"
