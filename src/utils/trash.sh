#!/bin/bash

source $(dirname "$(readlink -f "$0")")/utils/global.sh

if [[ -d ~/.local/share/Trash/files ]]; then
	put RED "Showing files in .local/share/Trash/files $TRASH"
	ls -Ahl ~/.local/share/Trash/files
	put NC "Should I clean Trash? "
	read -p "[Y/n]: " ANSW
	if [[ $ANSW == "y" ]]; then
	    rm -rf ~/.local/share/Trash/*
	    put GREEN "Trash: cleaned"
	else
	    put RED "Trash: not cleaned"
	fi
else
    put GREEN "Trash is empty, nothing to clean"
fi
