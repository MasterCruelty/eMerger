#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="flatpak"

put BLUE "Using $PKG $FLATPAK"

put RED "update: starting"
$PWR $PKG update
put GREEN "update: completed"

put RED "repair: starting"
$PWR $PKG repair
put GREEN "repair: completed"

put RED "uninstall unused extensions: starting"
$PWR $PKG uninstall --unused
put GREEN "uninstall unused extensions: completed"
