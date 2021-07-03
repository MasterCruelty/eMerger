#!/bin/bash

source src/utils/global.sh
printProgress "Setup: starting"

EXST=$(cat ~/.bashrc | grep -c "emerger.sh")
if [[ $EXST -ne 0 ]]; then
    printProgress "Alias 'up' already exists. Use 'up' or run './src/emerger.sh'"
    source src/test/integrity_check.sh
    printProgress "Setup: completed."
else
    echo "alias up='bash $(pwd)/src/emerger.sh'" >> ~/.bashrc
    chmod +x src/emerger.sh
    printProgress "Alias 'up' added.\nUse 'up' or run './src/emerger.sh'"
    source src/test/integrity_check.sh
    printProgress "Setup: completed."
fi

if [[ $1 != "fetch" ]]; then
    source src/utils/cache_gen.sh > src/utils/.cache
    md5sum src/utils/.cache | cut -d " " -f1 > src/utils/.md5
    chmod 775 src/utils/.cache
    chmod 775 src/utils/.md5

    TERMINAL=$(cat src/utils/.cache | head -n 2 | tail -n 1)
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
