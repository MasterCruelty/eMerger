#!/bin/bash

source src/utils/global.sh 2>>.log

if [[ $(grep -c "alias up=" ~/.bashrc) -lt 1 ]]; then
    put GREEN "Nothing to uninstall $CHECKMARK"
    exit 0
fi

put RED "Uninstall: starting"
sed -i "/alias up=/d" ~/.bashrc 2>>.log
put LOGO "Alias 'up' removed"

# Get favourite terminal
TERMINAL=$(cat src/utils/.cache | head -n 2 | tail -n 1)

# Remove cronjob, if it exists (and if the user can)
if [[ $(grep -c "utils/privileges" $(dirname "$(readlink -f "$0")")/src/utils/.cache) -gt 0 && $(crontab -l | grep -c "eMerger/update.sh") -gt 0 ]]; then
    sudo crontab -u $USER -l | grep -v "eMerger/update.sh"  | sudo crontab -u $USER -
    put LOGO "Cronjob successfully removed"
fi

# Remove .cache and .md5
rm -f src/utils/.cache 2>>.log
rm -f src/utils/.md5 2>>.log

put GREEN "Uninstall: completed $SAD"

if [[ $TERMINAL == "unknown" ]]; then
    exec bash
    exit 0
else
    read -p "$(echo -e ${RED}Press enter, this process will be killed${NORMAL})"
    
    $TERMINAL 2>>.log
    kill -9 $PPID
fi
