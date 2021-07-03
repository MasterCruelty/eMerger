#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="pacman"

printf "${GREEN}\nPackage manager detected: ${RED}Using $PKG $ARCH${NORMAL}\n"

printProgress "update: starting"
$PWR $PKG -Syy
printProgress "update: completed"

printProgress "upgrade: starting"
$PWR $PKG -Syu
printProgress "upgrade: completed"

printProgress "clean all: starting"
$PWR $PKG -R $($PKG -Qtdq)
printProgress "clean all: completed"


printf "\n"
