#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="pkg"

puts BLUE "Using $PKG $TERMUX"

puts RED "update: starting"
try $PWR $PKG update
puts GREEN "update: completed"

puts RED "upgrade: starting"
try $PWR $PKG upgrade
puts GREEN "upgrade: completed"

puts RED "autoclean: starting"
try $PWR $PKG autoclean
puts GREEN "autoclean: completed"
