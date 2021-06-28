#!/bin/bash

source src/utils/global.sh

sed -i "/alias up=/d" ~/.bashrc
printf "${RED}Alias 'up' removed\n"

printf "\nUninstallation completed\n${NORMAL}"

if [[ $1 == "fetch" ]]; then
    exit 0	
else
    exec bash
    exit 0
fi
