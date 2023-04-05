#!/bin/bash

source $(dirname "$(readlink -f "$0")")/utils/global.sh

if [[ -d ~/.local/share/Trash/files ]]; then
	puts RED "Showing files in .local/share/Trash/files $TRASH"
    du -sh ~/.local/share/Trash/files
	ls -Al ~/.local/share/Trash/files | tail -n +2
	puts NC "Should I clean Trash? "
	read -p "[Y/n]: " ANSW
	if [[ $ANSW == "y" ]]; then
	    rm -rf ~/.local/share/Trash/*
	    puts GREEN "Trash: cleaned"
	else
	    puts RED "Trash: not cleaned"
	fi
else
    puts GREEN "Trash is empty, nothing to clean"
fi
