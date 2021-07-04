#!/bin/bash

source src/utils/global.sh 2>>.errors

if [[ $(grep -c "alias up=" ~/.bashrc) -lt 1 ]]; then
    printf "${GREEN}Nothing to uninstall $CHECKMARK${NORMAL}\n"
    exit 0
fi

printProgress "Uninstall: starting"
sed -i "/alias up=/d" ~/.bashrc 2>>.errors
printf "${RED}Alias 'up' removed${NORMAL}\n"
printProgress "Uninstall: completed $SAD"

if [[ $1 != "fetch" ]]; then
    TERMINAL=$(cat src/utils/.cache | head -n 2 | tail -n 1)

    rm -f src/utils/.cache 2>>.errors
    rm -f src/utils/.md5 2>>.errors

    if [[ $TERMINAL == "unknown" ]]; then
        exec bash
        exit 0
    else
        printf "\n${RED}"
        read -p "Press enter, this process will be killed" answ
        printf "${NORMAL}"
        
        $TERMINAL 2>>.errors
        kill -9 $PPID
    fi
fi
