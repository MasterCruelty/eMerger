#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="rpm"

if [[ $(command -v yum) ]]; then
    PKG="yum"

    if [[ $(command -v dnf) ]]; then
        PKG="dnf"
    fi

    put BLUE "Using $PKG $RPM"

    put RED "update: starting"
    $PWR $PKG update
    put GREEN "update: completed"

    put RED "upgrade: starting"
    $PWR $PKG upgrade
    put GREEN "upgrade: completed"

    put RED "autoremove: starting"
    $PWR $PKG autoremove
    put GREEN "autoremove: completed"

    put RED "clean all: starting"
    $PWR $PKG clean all
    put GREEN "clean all: completed"
else
    put BLUE "\nUsing $PKG $RPM"

    put RED "freshen: starting"
    $PWR $PKG -l | xargs -I{} $PWR $PKG -F {}
    put GREEN "freshen: completed"
fi
