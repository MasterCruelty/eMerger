#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="zypper"

puts BLUE "Using $PKG $OPENSUSE"

puts RED "refresh: starting"
try $PWR $PKG refresh
puts GREEN "refresh: completed"

puts RED "update: starting"
try $PWR $PKG up 2>/dev/null || $PWR $PKG dup
puts GREEN "update: completed"

puts RED "remove dependencies: starting"
try $PWR $PKG rm chromium --clean-deps
puts GREEN "remove dependencies: completed"

puts RED "list unneeded packages: starting"
try $PWR $PKG packages --unneeded
puts GREEN "list unneeded packages: completed"
