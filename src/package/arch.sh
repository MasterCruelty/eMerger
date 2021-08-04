#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="pacman"

puts BLUE "Using $PKG $ARCH"

puts RED "update: starting"
$PWR $PKG -Syy
puts GREEN "update: completed"

puts RED "upgrade: starting"
$PWR $PKG -Syu
puts GREEN "upgrade: completed"

puts RED "clean all: starting"
$PWR $PKG -R $($PKG -Qtdq)
puts GREEN "clean all: completed"
