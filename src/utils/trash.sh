#!/bin/bash

source $(dirname "$(readlink -f "$0")")/utils/global.sh

if [[ -d ~/.local/share/Trash/files ]]; then
	printf "$RED\nShowing files in .local/share/Trash/files$NORMAL\n"
	ls -Ahl ~/.local/share/Trash/files
	sudo rm -rf ~/.local/share/Trash/*
	printProgress "Trash: cleaned"
else
    printProgress "\nTrash is empty, nothing to clean"
fi