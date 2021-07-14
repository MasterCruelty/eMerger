#!/bin/bash

source src/utils/global.sh 2>>.errors
printProgress "Setup: starting"

EXST=$(cat ~/.bashrc | grep -c "emerger.sh")
if [[ $EXST -ne 0 ]]; then
    printProgress "Alias 'up' already exists. Use 'up' or run './src/emerger.sh'"
    source src/test/integrity_check.sh 2>>.errors
    printProgress "Setup: completed $COOL"
else
    source src/utils/cache_gen.sh > src/utils/.cache 2>>.errors
    md5sum src/utils/.cache | cut -d " " -f1 > src/utils/.md5 2>>.errors
    chmod 775 src/utils/.cache 2>>.errors
    chmod 775 src/utils/.md5 2>>.errors
    
    echo "alias up='bash $(pwd)/src/emerger.sh'" >> ~/.bashrc
    chmod +x src/emerger.sh 2>>.errors
    printProgress "Alias 'up' added.\nUse 'up' or run './src/emerger.sh'"
    source src/test/integrity_check.sh 2>>.errors
    printProgress "Setup: completed $COOL"
fi

# Open a new terminal
TERMINAL=$(cat src/utils/.cache | head -n 2 | tail -n 1)
if [[ $TERMINAL == "unknown" ]]; then
    exec bash
    exit 0
else
    read -p "$(echo -e ${RED}Press enter, this process will be killed${NORMAL})"
    
    $TERMINAL 2>>.errors
    kill -9 $PPID
fi
