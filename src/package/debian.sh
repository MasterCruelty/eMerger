#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="apt-get"

if [[ $(command -v apt) ]]; then
    PKG="apt"

    put BLUE "Using $PKG $DEBIAN"

    put RED "update: starting"
    $PWR $PKG update
    put GREEN "update: completed"

    put RED "full-upgrade: starting"
    $PWR $PKG full-upgrade
    put GREEN "full-upgrade: completed"

    put RED "autoclean: starting"
    $PWR $PKG autoclean
    put GREEN "autoclean: completed"

    put RED "clean: starting"
    $PWR $PKG clean
    put GREEN "clean: completed"
else
    put BLUE "Using $PKG $DEBIAN"

    put RED "update: starting"
    $PWR $PKG update
    put GREEN "update: completed"

    put RED "dist-upgrade: starting"
    $PWR $PKG dist-upgrade
    put GREEN "dist-upgrade: completed"

    put RED "autoclean: starting"
    $PWR $PKG autoclean
    put GREEN "autoclean: completed"

    put RED "clean: starting"
    $PWR $PKG clean
    put GREEN "clean: completed"
fi
