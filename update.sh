#!/bin/bash

source $1src/utils/global.sh

# git pull from main
put RED "Update repository: starting"
if [[ $1 != "" ]]; then
    git -C $1 pull https://github.com/MasterCruelty/eMerger.git/
else
    git pull https://github.com/MasterCruelty/eMerger.git/
fi

# Instead of re-installing, use our tests to check if everything is okay
source $1src/test/integrity_check.sh $1 2>>$1.errors
put GREEN "Update repository: completed"

# Track successful update
date > $1.update

exit 0
