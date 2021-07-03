#!/bin/bash

# REF looks for where the file has been executed
# If the script is executed from `test/`, then no PAD is added
# If the script is executed from '.setup.sh', then it needs to know the PAD
REF=$(dirname "$(readlink -f ../$0)")
PAD=""
if [[ "$REF" != *"/eMerger/src" ]]; then
    PAD="/eMerger/src"
fi
SRC="$(cat $REF$PAD/utils/.cache | head -n 1)/src"

# check global.sh existence (printProgress is there)
if [[ -f $SRC/utils/global.sh ]]; then
    source $SRC/utils/global.sh
else
    printProgress "\n$SRC/utils/global.sh is missing: aborting script\n"
    exit 1
fi

# check ./src/emerger.sh existence
if [[ -f "$SRC/emerger.sh" ]]; then
    true
else
    printf "emerger.sh is missing: aborting script\n"
    exit 1
fi

# check existence of ./src/utils/*
printProgress "\ncheck ./src/utils/*: starting"
while read LINE; do
    if [[ -f "$SRC/utils/$LINE.sh" && $LINE != "" ]]; then
        printf "${LOGO}passed\t$LINE.sh $CHECKMARK${NORMAL}\n"
    else
        printProgress "$SRC/utils/$LINE.sh is missing: aborting script $CROSSMARK\n"
        exit 1
    fi
done < $SRC/utils/.utils
printProgress "check ./src/utils/*: completed"

# check existence of ./src/package/*
printProgress "check ./src/package/*: starting"
while read LINE; do
    if [[ -f "$SRC/package/$LINE.sh" && $LINE != "" ]]; then
        printf "${LOGO}passed\t$LINE.sh $CHECKMARK${NORMAL}\n"
    else
        printProgress "$SRC/package/$LINE.sh is missing: aborting script $CROSSMARK\n"
        exit 1
    fi
done < $SRC/package/.packages
printProgress "check ./src/package/*: completed\n"
