#!/bin/bash

#Setting colours with their codes.
GREEN="\e[1;32;49m"
LOGO="\e[2;37;49m"
NORMAL="\e[0m"
RED="\e[1;91;49m"

printProgress() {
    if [[ "$1" == *starting ]] || [[ "$1" == *privileges ]] || [[ "$1" == *already* ]] || [[ "$1" == *aborting* ]]; then
        printf "$RED$1\n$NORMAL"
    else
        printf "$GREEN$1\n$NORMAL"
    fi
}
