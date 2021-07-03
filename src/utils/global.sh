#!/bin/bash

# Colors
GREEN="\e[1;32;49m"
LOGO="\e[2;37;49m"
NORMAL="\e[0m"
RED="\e[1;91;49m"

# Emojis
ARCH="\U0001F3F9"
CHECKMARK="\U00002714"
COOL="\U0001F60E"
CROSSMARK="\U0000274C"
DEBIAN="\U0001F300"
FLATPAK="\U0001F4E6"
GENTOO="\U0001F427"
MONOCLE="\U0001F9D0"
OPENSUSE="\U0001F98E"
RPM="\U0001F920"
SAD="\U0001F622"
SNAP="\U0001F9A2"
TERMUX="\U0001F916"
TRASH="\U0001F4A9"

printProgress() {
    if [[ "$1" == *starting ]] || [[ "$1" == *privileges ]] || [[ "$1" == *already* ]] || [[ "$1" == *aborting* ]]; then
        printf "$RED$1\n$NORMAL"
    else
        printf "$GREEN$1\n$NORMAL"
    fi
}
