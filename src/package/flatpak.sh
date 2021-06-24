#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/checkpwr.sh)
PKG="flatpak"

printf "${GREEN}\nPackage manager detected: ${RED}Using $PKG${NORMAL}\n"

printProgress "update: starting"
$PWR $PKG update
printProgress "update: completed"

printProgress "repair: starting"
$PWR $PKG repair
printProgress "repair: completed"

printProgress "uninstall unused extensions: starting"
$PWR $PKG uninstall --unused
printProgress "uninstall unused extensions: completed"

printf "\n"
