#!/bin/bash


SRC=$(dirname "$(readlink -f "../$0")")
if [[ -f "$SRC/utils/global.sh" ]]; then
    source $SRC/utils/global.sh
else
    printf "global.sh is missing: abort.\n"
    exit 0
fi

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

if [[ -f "$SRC/updater.sh" ]]; then
    printProgress "updater.sh checked\nAll files checked."
    exit 0
fi
