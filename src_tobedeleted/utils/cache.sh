#!/bin/bash

source $(dirname "$(readlink -f "$0")")/utils/global.sh

if [[ -d ~/.cache ]]; then
	puts RED "Showing files in .cache $TRASH"
	du -sh ~/.cache
    ls -Al ~/.cache | tail -n +2
	puts NC "Should I clean caches? "
	read -p "[Y/n]: " ANSW
	if [[ $ANSW == "n" ]]; then
	    puts RED "Caches: not cleaned"
	else
	    rm -rf ~/.cache*
	    puts GREEN "Caches: cleaned"
	fi
else
    puts GREEN "Caches are empty, nothing to clean"
fi
