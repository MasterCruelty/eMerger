#!/bin/bash

if [[ $(stty size | awk '{print $2}') -ge 69 ]]; then
	cat ~/.logo
fi

src_path=$(dirname "$(readlink -f "$0")")
source "$src_path"/other/global.sh

# termux
if [[ $(command -v pkg) ]]; then
	source "$src_path"/package/termux.sh
	source "$src_path"/other/trash.sh
    exit 0;
#gentoo
elif [[ $(command -v emerge) ]]; then
	source "$src_path"/package/gentoo.sh
	source "$src_path"/other/trash.sh
    exit 0;
fi

# check privileges
source "$src_path"/other/privileges.sh

# snap
if [[ $(command -v snap) ]]; then
	source "$src_path"/package/snap.sh
fi

# debian
if [[ $(command -v apt-get) ]]; then
	source "$src_path"/package/debian.sh
# rpm
elif [[ $(command -v yum) ]]; then	
	source "$src_path"/package/rpm.sh
# arch
elif [[ $(command -v pacman) ]]; then	
	source "$src_path"/package/archlinux.sh
# not found
else
    printf "${RED}System not supported${NORMAL}"
fi

# check trash
source "$src_path"/other/trash.sh

printf "\n"
exit 0
