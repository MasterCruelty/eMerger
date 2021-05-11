#!/bin/bash

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
NORMAL=$(tput sgr0)

printf "${RED}\nSetup: starting\n${NORMAL}"

cp -f $(pwd)/.logo ~/.logo

EXST=$(cat ~/.bashrc | grep -c "updater.sh")
if [[ $EXST -ne 0 ]]; then
    printf "${RED}\nAlias 'up' already exists.\nUse 'up' or run './updater.sh'.\n\n${GREEN}Setup completed\n${NORMAL}"
    exit 0
else
    echo "alias up='bash $(pwd)/updater.sh'" >> ~/.bashrc
    chmod +x updater.sh
    printf "${GREEN}\nAlias 'up' added.\nUse 'up' or run './updater.sh'.\n\n${GREEN}Setup completed.\n${NORMAL}"
fi
