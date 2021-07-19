#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="snap"

put BLUE "Using $PKG $SNAP"

put RED "refresh: starting"
$PWR $PKG refresh
put GREEN "refresh: completed"
