#!/bin/bash

printf "${GREEN}\nSystem detected: ${RED}Using snap${NORMAL}"

printProgress "snap refresh: starting"
sudo snap refresh
printProgress "snap refresh: completed"