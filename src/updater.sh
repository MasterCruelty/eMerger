#!/bin/bash

cat ~/.logo

src_path="$(dirname "$(readlink -f "$0")")"
source "$src_path"/other/global.sh

# termux
if [[ -n "$(command -v pkg)" ]]; then
	source "$src_path"/package/termux.sh
	source "$src_path"/other/trash.sh
    exit 0;
#gentoo
elif [[ -n "$(command -v emerge)" ]]; then
	source "$src_path"/package/gentoo.sh
	source "$src_path"/other/trash.sh
    exit 0;
fi

# check privileges
source "$src_path"/other/privileges.sh

# debian
if [[ -n "$(command -v apt-get)" ]]; then
	source "$src_path"/package/debian.sh
# rpm
elif [[ -n "$(command -v yum)" ]]; then	
	source "$src_path"/package/rpm.sh
# arch
elif [[ -n "$(command -v pacman)" ]]; then	
	source "$src_path"/package/archlinux.sh
# not found
else
    printf "${RED}System not supported${NORMAL}"
fi

# snap
if [[ -n "$(command -v snap)" ]]; then
	source "$src_path"/package/snap.sh
fi

# check trash
source "$src_path"/other/trash.sh

printf "\n"
exit 0
