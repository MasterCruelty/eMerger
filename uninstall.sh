#!/bin/bash

source src/global.sh

rm ~/.logo
printf "${RED}File '.logo' removed\n${NORMAL}"
sed -i "/alias up=/d" ~/.bashrc
printf "${RED}Alias 'up' removed\n${NORMAL}"

printf "${RED}\nUninstallation completed\n${NORMAL}"

read -p "${RED}Press enter, the process  will be killed.\nIf your terminal closes, open a new one.${NORMAL}" text
kill -9 $PPID
exit 0
