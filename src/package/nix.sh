#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="nixos-rebuild switch"

put BLUE "Using $PKG $NIX"

put RED "upgrade: starting"
$PWR $PKG --upgrade
put GREEN "upgrade: completed"

put RED "repair: starting"
$PWR $PKG --repair
put GREEN "repair: completed"
