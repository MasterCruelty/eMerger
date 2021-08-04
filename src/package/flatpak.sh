#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="flatpak"

puts BLUE "Using $PKG $FLATPAK"

puts RED "update: starting"
$PWR $PKG update
puts GREEN "update: completed"

puts RED "repair: starting"
$PWR $PKG repair
puts GREEN "repair: completed"

puts RED "uninstall unused extensions: starting"
$PWR $PKG uninstall --unused
puts GREEN "uninstall unused extensions: completed"
