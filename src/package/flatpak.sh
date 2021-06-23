#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/checkpwr.sh)
PKG="flatpak"

printf "${GREEN}\nPackage manager detected: ${RED}Using $PKG${NORMAL}"

printProgress "flatpak update: starting"
$PWR $PKG update
printProgress "flatpak update: completed"

printProgress "flatpak repair: starting"
$PWR $PKG repair
printProgress "flatpak repair: completed"

printProgress "flatpak uninstall unused extensions: starting"
$PWR $PKG uninstall --unused
printProgress "flatpak uninstall unused extensions: completed"

printf "\n"
