#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="apt-get"

if [[ $(command -v apt) ]]; then
    PKG="apt"

    printf "${BLUE}\nUsing $PKG $DEBIAN${NORMAL}\n"

    printProgress "update: starting"
    $PWR $PKG update
    printProgress "update: completed"

    printProgress "full-upgrade: starting"
    $PWR $PKG full-upgrade
    printProgress "full-upgrade: completed"

    printProgress "autoclean: starting"
    $PWR $PKG autoclean
    printProgress "autoclean: completed"

    printProgress "clean: starting"
    $PWR $PKG clean
    printProgress "clean: completed"

    printProgress "autoremove: starting"
    $PWR $PKG autoremove
    printProgress "autoremove: completed"
else
    printf "${BLUE}\nUsing $PKG $DEBIAN${NORMAL}\n"

    printProgress "update: starting"
    $PWR $PKG update
    printProgress "update: completed"

    printProgress "dist-upgrade: starting"
    $PWR $PKG dist-upgrade
    printProgress "dist-upgrade: completed"

    printProgress "autoclean: starting"
    $PWR $PKG autoclean
    printProgress "autoclean: completed"

    printProgress "clean: starting"
    $PWR $PKG clean
    printProgress "clean: completed"
fi

printf "\n"
