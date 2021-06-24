#!/bin/bash

#I check for printProgress so I can use it later
SRC=$(dirname "$(readlink -f "../$0")")
if [[ -f "$SRC/utils/global.sh" ]]; then
    source $SRC/utils/global.sh
else
    printf "global.sh is missing: abort.\n"
    exit 0
fi

#I define an empty array for /utils files and I fill it with content of utils file.
file_utils=();
mapfile -t files_utils < "$SRC/utils/utils"
printProgress "checking /utils files: starting"

for i in "${files_utils[@]}" 
do
    if [[ -f "$SRC/utils/$i" ]]; then
        printProgress "$i checked\n"
    else
        printProgress "A file is missing: aborting."
	exit 0
    fi
done

printProgress "/utils files: all checked.\n"

#I define an ampty array for /package files and I fill it with content of package file.
file_package=();
mapfile -t files_package < "$SRC/utils/package"
printProgress "checking /package files: starting"

for i in "${files_package[@]}" 
do
    if [[ -f "$SRC/package/$i" ]]; then
        printProgress "$i checked\n"
    else
        printProgress "A file is missing: aborting."
	exit 0
    fi
done
printProgress "/package files: all checked.\n"

#In the end I check for updater.sh file.
if [[ -f "$SRC/updater.sh" ]]; then
    printProgress "updater.sh checked\nAll files checked."
    exit 0
fi
