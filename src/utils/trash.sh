#!/bin/bash

source $(dirname "$(readlink -f "$0")")/utils/global.sh

if [[ -d ~/.local/share/Trash/files ]]; then
	printf "${RED}\nShowing files in .local/share/Trash/files${NORMAL}\n"
	ls -hl ~/.local/share/Trash/files
	printf "Should I clean Trash? "
	read -p "[y/n]: " ANSW
	if [[ "$ANSW" == "y" ]]; then
	    sudo rm -rf ~/.local/share/Trash/*
	    printProgress "Trash: cleaned"
	else
	    printProgress "Trash: not cleaned"
	fi
else
    printProgress "\nTrash is empty, nothing to clean."
fi