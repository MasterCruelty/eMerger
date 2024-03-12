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

    puts BLUE "Using $PKG $RPM"

    puts RED "update: starting"
    try $PWR $PKG update
    puts GREEN "update: completed"

    puts RED "upgrade: starting"
    try $PWR $PKG upgrade
    puts GREEN "upgrade: completed"

    puts RED "autoremove: starting"
    try $PWR $PKG autoremove
    puts GREEN "autoremove: completed"

    puts RED "clean all: starting"
    try $PWR $PKG clean all
    puts GREEN "clean all: completed"
else
    puts BLUE "\nUsing $PKG $RPM"

    puts RED "freshen: starting"
    try $PWR $PKG -l | xargs -I{} $PWR $PKG -F {}
    puts GREEN "freshen: completed"
fi
