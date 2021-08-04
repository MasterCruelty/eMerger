#!/bin/bash

source $(dirname "$(readlink -f "$0")")/utils/global.sh

if [[ -d ~/.local/share/Trash/files ]]; then
	puts RED "Showing files in .local/share/Trash/files $TRASH"
	ls -Ahl ~/.local/share/Trash/files
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
