#!/bin/bash

cat ~/.logo

GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
NORMAL=$(tput sgr0)

PKG=""
#I find the absolute path of src folder
src_path="$(dirname "$(readlink -f "$0")")"
#I call printProgress function from another shell file
source "$src_path"/printProgress.sh

if [[ -n "$(command -v pkg)" ]]; then
	
	#I call the sh file for termux commands		
	source "$src_path"/systems/termux.sh	
    exit 1;

elif [[ -n "$(command -v emerge)" ]]; then
	
	#I call the sh file for gentoo commands		
	source "$src_path"/systems/gentoo.sh	
    exit 1;
fi

#I call this file to check sudo privileges of the user who is launching this script.
source "$src_path"/privileges.sh

if [[ -n "$(command -v apt-get)" ]]; then
	
	#I call the sh file for debian commands		
	source "$src_path"/systems/debian.sh	

elif [[ -n "$(command -v yum)" ]]; then
	
	#I call the sh file for fedora commands		
	source "$src_path"/systems/fedora.sh	

elif [[ -n "$(command -v pacman)" ]]; then

	#I call the sh file for archlinux commands		
	source "$src_path"/systems/archlinux.sh	
else
    printf "${RED}System not supported${NORMAL}"
fi

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

printf "\n"
exit 0
