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

    printf "${BLUE}\nUsing $PKG $RPM${NORMAL}\n"

    printProgress "update: starting"
    $PWR $PKG update
    printProgress "update: completed"

    printProgress "upgrade: starting"
    $PWR $PKG upgrade
    printProgress "upgrade: completed"

    printProgress "autoremove: starting"
    $PWR $PKG autoremove
    printProgress "autoremove: completed"

    printProgress "clean all: starting"
    $PWR $PKG clean all
    printProgress "clean all: completed"
else
    printf "${BLUE}\nUsing $PKG $RPM${NORMAL}\n"

    printProgress "freshen: starting"
    $PWR $PKG -l | xargs -I{} $PWR $PKG -F {}
    printProgress "freshen: completed"
fi

printf "\n"


