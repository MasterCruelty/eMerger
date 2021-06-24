#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/checkpwr.sh)
PKG="zypper"

printf "${GREEN}\nPackage manager detected: ${RED}Using $PKG${NORMAL}"

printProgress "refresh: starting"
$PWR $PKG refresh
printProgress "refresh: completed"

printProgress "update: starting"
$PWR $PKG up 2>/dev/null || $PWR $PKG dup
printProgress "update: completed"

printf "\n"
