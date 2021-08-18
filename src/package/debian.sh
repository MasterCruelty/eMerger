#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="apt-get"

if [[ $(command -v apt) ]]; then
    PKG="apt"

    puts BLUE "Using $PKG $DEBIAN"

    puts RED "update: starting"
    $PWR $PKG update
    puts GREEN "update: completed"

    puts RED "full-upgrade: starting"
    $PWR $PKG full-upgrade
    puts GREEN "full-upgrade: completed"

    puts RED "autoremove: starting"
    $PWR $PKG autoremove
    puts GREEN "autoremove: completed"

    puts RED "autoclean: starting"
    $PWR $PKG autoclean
    puts GREEN "autoclean: completed"

    puts RED "clean: starting"
    $PWR $PKG clean
    puts GREEN "clean: completed"
else
    puts BLUE "Using $PKG $DEBIAN"

    puts RED "update: starting"
    $PWR $PKG update
    puts GREEN "update: completed"

    puts RED "dist-upgrade: starting"
    $PWR $PKG dist-upgrade
    puts GREEN "dist-upgrade: completed"

    puts RED "autoremove: starting"
    $PWR $PKG autoremove
    puts GREEN "autoremove: completed"

    puts RED "autoclean: starting"
    $PWR $PKG autoclean
    puts GREEN "autoclean: completed"

    puts RED "clean: starting"
    $PWR $PKG clean
    puts GREEN "clean: completed"
fi
