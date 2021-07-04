#!/bin/bash

source src/utils/global.sh

printProgress "Uninstall: starting"
sed -i "/alias up=/d" ~/.bashrc
printf "${RED}Alias 'up' removed\n${NORMAL}"
printProgress "Uninstall: completed $SAD"

if [[ $1 != "fetch" ]]; then
    TERMINAL=$(cat src/utils/.cache | head -n 2 | tail -n 1)
    
    rm -f src/utils/.cache 2>/dev/null
    rm -f src/utils/.md5 2>/dev/null

    if [[ $TERMINAL == "unknown" ]]; then
        exec bash
        exit 0
    else
        printf "\n${RED}"
        read -p "Press enter, this process will be killed" answ
        printf "${NORMAL}"
        
        $TERMINAL
        kill -9 $PPID
    fi
fi
