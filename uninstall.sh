#!/bin/bash

source src/utils/global.sh

printProgress "Uninstall: starting"
sed -i "/alias up=/d" ~/.bashrc
printf "${RED}Alias 'up' removed\n${NORMAL}"
printProgress "Uninstall: completed"

if [[ $1 != "fetch" ]]; then
    exec bash
    exit 0
fi
