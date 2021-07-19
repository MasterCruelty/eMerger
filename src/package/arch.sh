#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="pacman"

put BLUE "Using $PKG $ARCH"

put RED "update: starting"
$PWR $PKG -Syy
put GREEN "update: completed"

put RED "upgrade: starting"
$PWR $PKG -Syu
put GREEN "upgrade: completed"

put RED "clean all: starting"
$PWR $PKG -R $($PKG -Qtdq)
put GREEN "clean all: completed"
