#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="snap"

puts BLUE "Using $PKG $SNAP"

puts RED "refresh: starting"
try $PWR $PKG refresh
puts GREEN "refresh: completed"
