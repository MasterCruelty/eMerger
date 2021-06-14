#!/bin/bash

GREEN=$(tput setaf 2)
RED=$(tput setaf 1)
NORMAL=$(tput sgr0)

printProgress() {
    if [[ "$1" == *starting ]] || [[ "$1" == *privileges ]] || [[ "$1" == *already* ]] || [[ "$1" == *aborting* ]]; then
	    printf "${RED}\n$1\n${NORMAL}"
    else
	    printf "${GREEN}$1\n${NORMAL}"
    fi
}