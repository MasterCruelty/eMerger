#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/checkpwr.sh)

printf "${GREEN}\nPackage manager detected: ${RED}Using snap${NORMAL}"

printProgress "refresh: starting"
$PWR snap refresh
printProgress "refresh: completed"

printf "\n"
