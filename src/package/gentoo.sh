#!/bin/bash

src_path="$(dirname "$(readlink -f "$0")")"
source "$src_path"/other/global.sh

PKG="emerge"

printf "${GREEN}System detected: ${RED}Using $PKG\n${NORMAL}"

printProgress "syncing: starting"
$PKG --sync
printProgress "syncing: completed"

printProgress "update: starting"
$PKG --update --deep --newuse --with-bdeps y @world --ask
printProgress "update: completed"

printProgress "deepclean: starting"
$PKG --depclean --ask
revdep-rebuild
printProgress "deepclean: completed"
