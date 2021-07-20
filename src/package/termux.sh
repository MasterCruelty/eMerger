#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="pkg"

put BLUE "Using $PKG $TERMUX"

put RED "update: starting"
$PWR $PKG update
put GREEN "update: completed"

put RED "upgrade: starting"
$PWR $PKG upgrade
put GREEN "upgrade: completed"

put RED "autoclean: starting"
$PWR $PKG autoclean
put GREEN "autoclean: completed"
