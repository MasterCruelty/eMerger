#!/bin/bash

src_path=$(dirname "$(readlink -f "$0")")
source "$src_path"/utils/global.sh

PKG="pkg"

printf "${GREEN}\nSystem detected: ${RED}Using $PKG\n${NORMAL}"

printProgress "update: starting"
$PKG update
printProgress "update: completed"

printProgress "upgrade: starting"
$PKG upgrade
printProgress "upgrade: completed"

printProgress "autoclean: starting"
$PKG autoclean
printProgress "autoclean: completed"
