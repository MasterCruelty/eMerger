#!/bin/bash

source $1src/utils/global.sh

# git pull from main
printProgress "Update repository: starting"
if [[ $1 != "" ]]; then
    git -C $1 pull https://www.github.com/MasterCruelty/eMerger
else
    git pull https://www.github.com/MasterCruelty/eMerger
fi

# Instead of re-installing, use our tests to check if everything is okay
source $1src/test/integrity_check.sh $1 2>>$1.errors
printProgress "Update repository: completed"

# Track successful update
date > $1.update

exit 0
