#!/bin/bash

source src/utils/global.sh

# git pull from main
printProgress "Update repository: starting"
git pull https://www.github.com/MasterCruelty/eMerger

# re-install but keep old caches
source uninstall.sh "fetch" 1>/dev/null
source setup.sh "fetch" 1>/dev/null
printProgress "Update repository: completed"

exit 0
