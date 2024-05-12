#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="yay"

puts BLUE "Using $PKG $ARCH"

puts RED "update AUR packages: starting"
try $PKG -Syu
puts GREEN "update AUR packages: starting"
