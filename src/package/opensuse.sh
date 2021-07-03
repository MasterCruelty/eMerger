#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="zypper"

printf "${GREEN}\nPackage manager detected: ${RED}Using $PKG $OPENSUSE${NORMAL}\n"

printProgress "refresh: starting"
$PWR $PKG refresh
printProgress "refresh: completed"

printProgress "update: starting"
$PWR $PKG up 2>/dev/null || $PWR $PKG dup
printProgress "update: completed"

printProgress "remove dependencies: starting"
$PWR $PKG rm chromium --clean-deps
printProgress "remove dependencies: completed"

printProgress "list unneeded packages: starting"
$PWR $PKG packages --unneeded
printProgress "list unneeded packages: completed"

printf "\n"
