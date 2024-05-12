#!/bin/bash

source $(dirname "$(readlink -f "$0")")/utils/global.sh

puts RED "\nChecking for sudo privileges $MONOCLE"
sudo -v >/dev/null 2>&1
if [[ $(echo $?) -eq 0 ]]; then
    puts GREEN "Access granted\n"
else
    puts RED "Can't access: aborting script\n"
    exit 1
fi
