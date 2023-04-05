#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="pacman"

puts BLUE "Using $PKG $ARCH"

puts RED "update: starting"
try $PWR $PKG -Syy
puts GREEN "update: completed"

puts RED "upgrade: starting"
try $PWR $PKG -Syu
puts GREEN "upgrade: completed"

puts RED "clean pacman caches: starting"
try $PWR paccache -r
puts GREEN "clean pacman caches: starting"

puts RED "update AUR packages: starting"
try $PWR yay -Syu
puts GREEN "update AUR packages: starting"
