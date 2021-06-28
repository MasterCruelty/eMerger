#!/bin/bash

source src/utils/global.sh

#I do the git pull from the repository
printProgress "Fetching repository: starting"
git pull  https://www.github.com/MasterCruelty/Updater
printProgress "Fetching repository: done\n"

#I launch uninstall and setup
printProgress "Uninstalling old version and setup: starting"
bash uninstall.sh "fetch"  
bash setup.sh "fetch"
printProgress "Uninstalling old version and setup: done"
exec bash
