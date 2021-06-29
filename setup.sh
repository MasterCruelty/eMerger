#!/bin/bash

source src/utils/global.sh
printProgress "Setup: starting"

EXST=$(cat ~/.bashrc | grep -c "updater.sh")
if [[ $EXST -ne 0 ]]; then
    printProgress "Alias 'up' already exists. Use 'up' or run './src/updater.sh'"
    source src/test/integrity_check.sh
    printProgress "Setup: completed."
else
    echo "alias up='bash $(pwd)/src/updater.sh'" >> ~/.bashrc
    chmod +x src/updater.sh
    printProgress "Alias 'up' added.\nUse 'up' or run './src/updater.sh'"
    source src/test/integrity_check.sh
    printProgress "Setup: completed."
fi

if [[ $1 != "fetch" ]]; then
    source src/utils/cache_gen.sh > src/utils/.cache
    md5sum src/utils/.cache | cut -d " " -f1 > src/utils/.md5
    chmod 775 src/utils/.cache
    chmod 775 src/utils/.md5

    exec bash
    exit 0
fi
