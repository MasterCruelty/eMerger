#!/bin/bash

# Keeping track of exact time
date "+%D %T:%N" >> $1.log

source $1src/utils/global.sh

# git pull from main
put RED "Update repository: starting"
if [[ $1 != "" ]]; then
    git -C $1 pull https://github.com/MasterCruelty/eMerger.git/
else
    git pull https://github.com/MasterCruelty/eMerger.git/
fi

# Instead of re-installing, use our tests to check if everything is okay
source $1src/test/integrity_check.sh $1 2>>$1.log
put GREEN "Update repository: completed"

exit 0
