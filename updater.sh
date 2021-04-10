#!/bin/bash

RED=$(tput setaf 1)
NORMAL=$(tput sgr0)

if [[ -n "$(command -v apt-get)" ]]; then
    PKG="apt-get"
    if [[ -n "$(command -v apt)" ]]; then
        PKG="apt"
    fi
    
    printf "${RED}Using $PKG\n${NORMAL}"

    printf "${RED}\nupdate: starting\n${NORMAL}"
    sudo $PKG update

    printf "${RED}\nupgrade: starting\n${NORMAL}"
    sudo $PKG upgrade

    printf "${RED}\nautoclean: starting\n${NORMAL}"
    sudo $PKG autoclean

    printf "${RED}\nautoremove: starting\n${NORMAL}"
    sudo $PKG autoremove
elif [[ -n "$(command -v yum)" ]]; then
    PKG="yum"
    if [[ -n "$(command -v dnf)" ]]; then
        PKG="dnf"
    fi

    printf "${RED}Using $PKG\n\n${NORMAL}"

    printf "${RED}\nupdate: starting\n${NORMAL}"
    sudo $PKG update

    printf "${RED}\nupgrade: starting\n${NORMAL}"
    sudo $PKG upgrade

    printf "${RED}\nclean all: starting\n${NORMAL}"
    sudo $PKG clean all
else
    printf "${RED}System non supported\n${NORMAL}"
fi