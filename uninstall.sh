#!/bin/bash

RED=$(tput setaf 1)
NORMAL=$(tput sgr0)

printf "${RED}File '.logo' removed ${NORMAL}"
rm ~/.logo
printf "${RED}Alias 'up' removed\n${NORMAL}"
sed -i "/alias up=/d" ~/.bashrc

printf "${RED}\nUninstallation completed\n${NORMAL}"

read -p "${RED}Press enter, the terminal will be closed${NORMAL}" text
kill -9 $PPID
exit 0