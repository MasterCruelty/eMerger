#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="emerge"

put BLUE "Using $PKG $GENTOO"

put RED "syncing: starting"
$PWR $PKG --sync
put GREEN "syncing: completed"

put RED "update: starting"
$PWR $PKG --update --deep --newuse --with-bdeps y @world --ask
put GREEN "update: completed"

put RED "deepclean: starting"
$PWR $PKG --depclean --ask
revdep-rebuild
put GREEN "deepclean: completed"
