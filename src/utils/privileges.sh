#!/bin/bash

source $(dirname "$(readlink -f "$0")")/utils/global.sh

printProgress "Checking for sudo privileges"
sudo -v >/dev/null 2>&1
if [[ $(echo $?) -eq 0 ]]; then
    printProgress "Access granted"
else
    printProgress "Can't access: aborting script\n"
    exit 1
fi

