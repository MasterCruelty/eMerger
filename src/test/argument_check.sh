#!/bin/bash

CONTAIN=0
ARGS=(
    "-help"
    "-au"
    "-ni"
    "-nl"
    "-nt"
    "-w"
)

for ARGU in $@; do
    if [[ ${ARGS[*]} =~ $ARGU ]]; then
        CONTAIN=1
    else
        CONTAIN=0
        break
    fi
done

if [[ $CONTAIN != 1 ]]; then
    printf "No such command, try \"up -help\"\n"
    exit 1
fi