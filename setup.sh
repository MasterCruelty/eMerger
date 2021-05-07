#!/bin/bash

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
NORMAL=$(tput sgr0)

sed -i "4i cat $(pwd)/logo" $(pwd)/updater.sh
sed -i "5d" $(pwd)/updater.sh

printf "${RED}\nSetup: starting\n${NORMAL}"

EXST=$(cat ~/.bashrc | grep -c "updater.sh")
if [[ $EXST -ne 0 ]]; then
    printf "${RED}\nAlias 'up' already exists.\nUse 'up' or run './updater.sh'.\n\n${GREEN}Setup completed\n${NORMAL}"
    exit 0
else
    echo "alias up='bash $(pwd)/updater.sh'" >> ~/.bashrc
    chmod +x updater.sh
    printf "${GREEN}\nAlias 'up' added.\nUse 'up' or run './updater.sh'.\n\n${GREEN}Setup completed.\n${NORMAL}"
fi
