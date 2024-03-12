#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="emerge"

puts BLUE "Using $PKG $GENTOO"

puts RED "syncing: starting"
try $PWR $PKG --sync
puts GREEN "syncing: completed"

puts RED "update: starting"
try $PWR $PKG --update --deep --newuse --with-bdeps y @world --ask
puts GREEN "update: completed"

puts RED "deepclean: starting"
try $PWR $PKG --depclean --ask
revdep-rebuild
puts GREEN "deepclean: completed"
