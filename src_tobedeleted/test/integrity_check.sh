#!/bin/bash

# REF looks for where the file has been executed
# If the script is updated by the cronjob, it contains an argument $1
# If the script is executed from `test/`, then no PAD is added
# If the script is executed from '.setup.sh', then it needs to know the PAD
SRC=""
if [[ $1 != "" ]]; then
    SRC="$1src"
else
    REF=$(dirname "$(readlink -f ../$0)")
    PAD=""
    if [[ $REF != *"/eMerger/src" ]]; then
        PAD="/eMerger/src"
    fi
    SRC="$(cat $REF$PAD/utils/.cache | head -n 1)/src"
fi

# check global.sh existence (puts is there)
if [[ -f $SRC/utils/global.sh ]]; then
    source $SRC/utils/global.sh
else
    puts RED "\n$SRC/utils/global.sh is missing: aborting script\n"
    exit 1
fi

# check ./src/emerger.sh existence
if [[ -f "$SRC/emerger.sh" ]]; then
    true
else
    puts NC "emerger.sh is missing: aborting script\n"
    exit 1
fi

LIST=$SRC/test/list/

# check existence of ./src/utils/*
puts RED "\ncheck ./src/utils/*: starting"
while read LINE; do
    if [[ -f "$SRC/utils/$LINE" && $LINE != "" ]]; then
        puts LOGO "passed\t$LINE $NORMAL$GREEN$CHECKMARK"
    else
        puts RED "$SRC/utils/$LINE is missing: aborting script $CROSSMARK"
        exit 1
    fi
done < $LIST.utils
puts GREEN "check ./src/utils/*: completed"

# check existence of ./src/package/*
puts RED "check ./src/package/*: starting"
while read LINE; do
    if [[ -f "$SRC/package/$LINE" && $LINE != "" ]]; then
        puts LOGO "passed\t$LINE $NORMAL$GREEN$CHECKMARK"
    else
        puts RED "$SRC/package/$LINE is missing: aborting script $CROSSMARK"
        exit 1
    fi
done < $LIST.packages
puts GREEN "check ./src/package/*: completed"

# check existence of ./src/test/*
puts RED "check ./src/test/*: starting"
while read LINE; do
    if [[ -f "$SRC/test/$LINE" && $LINE != "" ]]; then
        puts LOGO "passed\t$LINE $NORMAL$GREEN$CHECKMARK"
    else
        puts RED "$LINE is missing: aborting script $CROSSMARK"
        exit 1
    fi
done < $LIST.tests
puts GREEN "check ./src/test/*: completed\n"
