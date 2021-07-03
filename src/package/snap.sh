#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="snap"

printf "${GREEN}\nPackage manager detected: ${RED}Using $PKG $SNAP${NORMAL}\n"

printProgress "refresh: starting"
$PWR $PKG refresh
printProgress "refresh: completed"

printf "\n"
