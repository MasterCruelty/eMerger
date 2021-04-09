#!/bin/bash
RED=$(tput setaf 1)
NORMAL=$(tput sgr0)

if [[ -n "$(command -v apt-get)" ]]; then
    PKG="apt-get"
    if [[ -n "$(command -v apt)" ]]; then
        PKG="apt"
    
    printf "${RED}Using $PKG\n\n${NORMAL}"

    printf "${RED}update: starting\n${NORMAL}"
    sudo $PKG update
    printf "\n"

    printf "${RED}upgrade: starting\n${NORMAL}"
    sudo $PKG upgrade
    printf "\n"

    printf "${RED}autoclean: starting\n${NORMAL}"
    sudo $PKG autoclean
    printf "\n"

    printf "${RED}autoremove: starting\n${NORMAL}"
    sudo $PKG autoremove
    printf "\n"
    fi
elif [[ -n "$(command -v yum)" ]]; then
    PKG="yum"
    if [[ -n "$(command -v dnf)" ]]; then
        PKG="dnf"

    printf "${RED}Using $PKG\n\n${NORMAL}"

    printf "${RED}update: starting\n${NORMAL}"
    sudo $PKG update
    printf "\n"

    printf "${RED}upgrade: starting\n${NORMAL}"
    sudo $PKG upgrade
    printf "\n"

    printf "${RED}clean all: starting\n${NORMAL}"
    sudo $PKG clean all
    printf "\n"
    fi
else
    printf "${RED}System non supported\n${NORMAL}"
fi