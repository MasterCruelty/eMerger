#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="zypper"

put BLUE "Using $PKG $OPENSUSE"

put RED "refresh: starting"
$PWR $PKG refresh
put GREEN "refresh: completed"

put RED "update: starting"
$PWR $PKG up 2>/dev/null || $PWR $PKG dup
put GREEN "update: completed"

put RED "remove dependencies: starting"
$PWR $PKG rm chromium --clean-deps
put GREEN "remove dependencies: completed"

put RED "list unneeded packages: starting"
$PWR $PKG packages --unneeded
put GREEN "list unneeded packages: completed"
