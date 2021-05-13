#!/bin/bash

cat ~/.logo

GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
NORMAL=$(tput sgr0)

PKG=""

printProgress() {
    if [[ "$1" == *starting ]] || [[ "$1" == *privileges ]] || [[ "$1" == *aborting* ]]; then
	    printf "${RED}\n$1\n${NORMAL}"
    else
	    printf "${GREEN}$1\n${NORMAL}"
    fi
}

if [[ -n "$(command -v pkg)" ]]; then
    PKG="pkg"

    printf "${GREEN}System detected: ${RED}Using $PKG\n${NORMAL}"

    printProgress "update: starting"
    $PKG update
    printProgress "update: completed"

    printProgress "upgrade: starting"
    $PKG upgrade
    printProgress "upgrade: completed"

    printProgress "autoclean: starting"
    $PKG autoclean
    printProgress "autoclean: completed\n"

    exit 1;
elif [[ -n "$(command -v emerge)" ]]; then
    PKG="emerge"

    printf "${GREEN}System detected: ${RED}Using $PKG\n${NORMAL}"

    printProgress "syncing: starting"
    $PKG --sync
    printProgress "syncing: completed"

    printProgress "update: starting"
    $PKG --update --deep --newuse --with-bdeps y @world --ask
    printProgress "update: completed"

    printProgress "deepclean: starting"
    $PKG --depclean --ask
    revdep-rebuild
    printProgress "deepclean: completed\n"

    exit 1;
fi

printProgress "Checking for sudo privileges"
sudo -v >/dev/null 2>&1
if [[ "$(echo $?)" -eq 0 ]]; then
    printProgress "Access granted.\n"
else
    printProgress "Can't access: aborting script.\n"
    exit 1
fi

if [[ -n "$(command -v apt-get)" ]]; then
    PKG="apt-get"
    if [[ -n "$(command -v apt)" ]]; then
        PKG="apt"
    fi
    
    printf "${GREEN}System detected: ${RED}Using $PKG\n${NORMAL}"
    
    printProgress "update: starting"
    sudo $PKG update
    printProgress "update: completed"

    printProgress "upgrade: starting"
    sudo $PKG upgrade
    printProgress "upgrade: completed"

    printProgress "autoclean: starting"
    sudo $PKG autoclean
    printProgress "autoclean: completed"

    printProgress "autoremove: starting"
    sudo $PKG autoremove
    printProgress "autoremove: completed"
elif [[ -n "$(command -v yum)" ]]; then
    PKG="yum"
    if [[ -n "$(command -v dnf)" ]]; then
        PKG="dnf"
    fi

    printf "${GREEN}System detected: ${RED}Using $PKG\n${NORMAL}"

    printProgress "update: starting"
    sudo $PKG update
    printProgress "update: completed"

    printProgress "upgrade: starting"
    sudo $PKG upgrade
    printProgress "upgrade: completed"

    printProgress "cleanAll: starting"
    sudo $PKG clean all
    printProgress "cleanAll: completed"
elif [[ -n "$(command -v pacman)" ]]; then
    PKG="pacman"

    printf "${GREEN}System detected: ${RED}Using $PKG\n${NORMAL}"

    printProgress "update: starting"
    sudo $PKG -Syy
    printProgress "update: completed"

    printProgress "upgrade: starting"
    sudo $PKG -Syu
    printProgress "upgrade: completed"

    printProgress "cleanAll: starting"
    sudo $PKG -R $($PKG -Qtdq)
    printProgress "cleanAll: completed"
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
