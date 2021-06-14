#!/bin/bash

cat ~/.logo


#I find the absolute path of src folder
src_path="$(dirname "$(readlink -f "$0")")"
#I call printProgress function from another shell file
source "$src_path"/global.sh

if [[ -n "$(command -v pkg)" ]]; then
	#I call the sh file for termux commands		
	source "$src_path"/package/termux.sh
	source "$src_path"/other/trash.sh
    exit 0;

elif [[ -n "$(command -v emerge)" ]]; then
	#I call the sh file for gentoo commands		
	source "$src_path"/package/gentoo.sh
	source "$src_path"/other/trash.sh
    exit 0;
fi

#I call this file to check sudo privileges of the user who is launching this script.
source "$src_path"/other/privileges.sh

if [[ -n "$(command -v apt-get)" ]]; then
	#I call the sh file for debian commands		
	source "$src_path"/package/debian.sh

elif [[ -n "$(command -v yum)" ]]; then
	#I call the sh file for rpm commands		
	source "$src_path"/package/rpm.sh

elif [[ -n "$(command -v pacman)" ]]; then
	#I call the sh file for archlinux commands		
	source "$src_path"/package/archlinux.sh
else
    printf "${RED}System not supported${NORMAL}"
fi

if [[ -n "$(command -v snap)" ]]; then
	source "$src_path"/package/snap.sh
fi

printf "\n"
source "$src_path"/other/trash.sh

printf "\n"
exit 0
