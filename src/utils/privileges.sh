#!/bin/bash

source $(dirname "$(readlink -f "$0")")/utils/global.sh

put RED "\nChecking for sudo privileges $MONOCLE"
sudo -v >/dev/null 2>&1
if [[ $(echo $?) -eq 0 ]]; then
    put GREEN "Access granted\n"
else
    put RED "Can't access: aborting script\n"
    exit 1
fi
