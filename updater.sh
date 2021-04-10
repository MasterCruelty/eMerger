#!/bin/bash

RED=$(tput setaf 1)
GREEN=$(tput setaf 2)
NORMAL=$(tput sgr0)

printProgress(){
    if [[ "$2" == "starting" ]]; then
	printf "${RED}\n$1 $2\n${NORMAL}"
    fi
    if [[ "$2" == "completed" ]]; then
	printf "${GREEN}\n$1 $2\n${NORMAL}"
    fi
}

if [[ -n "$(command -v apt-get)" ]]; then
    PKG="apt-get"
    if [[ -n "$(command -v apt)" ]]; then
        PKG="apt"
    fi
    
    printf "${RED}Using $PKG\n${NORMAL}"
    
    printProgress update: starting
    sudo $PKG update
    printProgress update: completed

    printProgress upgrade: starting
    sudo $PKG upgrade
    printProgress upgrade: completed

    printProgress autoclean: starting
    sudo $PKG autoclean
    printProgress autoclean: completed

    printProgress autoremove: starting
    sudo $PKG autoremove
    printProgress autoremove: completed
elif [[ -n "$(command -v yum)" ]]; then
    PKG="yum"
    if [[ -n "$(command -v dnf)" ]]; then
        PKG="dnf"
    fi

    printf "${RED}Using $PKG\n\n${NORMAL}"

    printProgress update: starting
    sudo $PKG update
    printProgress update: completed

    printf "${RED}\nupgrade: starting\n${NORMAL}"
    printProgress upgrade: starting
    sudo $PKG upgrade
    printProgress upgrade: completed

    printProgress cleanAll: starting
    sudo $PKG clean all
    printProgress cleanAll: completed
else
    printf "${RED}System non supported\n${NORMAL}"
fi
