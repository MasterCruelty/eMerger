#!/bin/bash

SRC=$(dirname "$(readlink -f ../$0)")

# check global.sh existence (printProgress is there)
if [[ -f $SRC/utils/global.sh ]]; then
    source $SRC/utils/global.sh
else
    printf "global.sh is missing: aborting script"
    exit 0
fi

# check ./src/updater.sh existence
if [[ -f "$SRC/updater.sh" ]]; then
    true
else
    printf "updater.sh is missing: aborting script"
    exit 0
fi

# check existence of ./src/utils/*
printProgress "check ./src/utils/*: starting"
while read LINE; do
    if [[ -f "$SRC/utils/$LINE.sh" && $LINE != "" ]]; then
        printf "passed\t$LINE.sh\n"
    else
        printProgress "$SRC/utils/$LINE.sh is missing: aborting script"
        exit 0
    fi
done < $SRC/utils/.utils
printProgress "check ./src/utils/*: completed"

# check existence of ./src/package/*
printProgress "check ./src/package/*: starting"
while read LINE; do
    if [[ -f "$SRC/package/$LINE.sh" && $LINE != "" ]]; then
        printf "passed\t$LINE.sh\n"
    else
        printProgress "$SRC/package/$LINE.sh is missing: aborting script"
        exit 0
    fi
done < $SRC/utils/.packages
printProgress "check ./src/package/*: completed"