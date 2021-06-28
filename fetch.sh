#!/bin/bash

source src/utils/global.sh

printProgress "Fetching repository: starting"
git pull  https://www.github.com/MasterCruelty/Updater
printProgress "Fetching repository: done\n"

printProgress "Uninstalling old version and setup: starting"
bash uninstall.sh "fetch"  
bash setup.sh "fetch"
printProgress "Uninstalling old version and setup: done"
exec bash
