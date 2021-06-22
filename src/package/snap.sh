#!/bin/bash

printf "${GREEN}\nPackage manager detected: ${RED}Using snap${NORMAL}"

printProgress "snap refresh: starting"
sudo snap refresh
printProgress "snap refresh: completed"

printf "\n"
