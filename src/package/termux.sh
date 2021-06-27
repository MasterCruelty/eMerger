#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="pkg"

printf "${GREEN}\nPackage manager detected: ${RED}Using $PKG${NORMAL}\n"

printProgress "update: starting"
$PWR $PKG update
printProgress "update: completed"

printProgress "upgrade: starting"
$PWR $PKG upgrade
printProgress "upgrade: completed"

printProgress "autoclean: starting"
$PWR $PKG autoclean
printProgress "autoclean: completed"

printf "\n"
