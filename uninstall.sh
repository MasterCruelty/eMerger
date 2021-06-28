#!/bin/bash

source src/utils/global.sh

sed -i "/alias up=/d" ~/.bashrc
printf "${RED}Alias 'up' removed\n"

printf "\nUninstallation completed\n${NORMAL}"

exec bash
exit 0
