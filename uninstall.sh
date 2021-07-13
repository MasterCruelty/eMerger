#!/bin/bash

source src/utils/global.sh 2>>.errors

if [[ $(grep -c "alias up=" ~/.bashrc) -lt 1 ]]; then
    printf "${GREEN}Nothing to uninstall $CHECKMARK${NORMAL}\n"
    exit 0
fi

printProgress "Uninstall: starting"
sed -i "/alias up=/d" ~/.bashrc 2>>.errors
printf "${RED}Alias 'up' removed${NORMAL}\n"

# Get favourite terminal
TERMINAL=$(cat src/utils/.cache | head -n 2 | tail -n 1)

# Remove cronjob, if it exists (and if the user can)
if [[ $(grep -c "utils/privileges" $(dirname "$(readlink -f "$0")")/src/utils/.cache) -gt 0 && $(crontab -l | grep -c "eMerger/update.sh") -gt 0 ]]; then
    sudo crontab -u $USER -l | grep -v "eMerger/update.sh"  | sudo crontab -u $USER -
    printProgress "Cronjob successfully removed $SAD"
fi

# Remove .cache and .md5
rm -f src/utils/.cache 2>>.errors
rm -f src/utils/.md5 2>>.errors

printProgress "Uninstall: completed $SAD"

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
