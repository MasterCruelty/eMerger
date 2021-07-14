#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

if [[ $(grep -c "utils/privileges" $(dirname "$(readlink -f "$0")")/utils/.cache) -lt 1 ]]; then
    printProgress "Sorry, but this command can't be executed without sudo privileges $MONOCLE"
    exit 1
fi

if [[ ! $(command -v crontab) ]]; then
    printf "${RED}Package crontab is required.\nInstall it and repeat the command.${NORMAL}\n"
    exit 1
fi

if [[ $(crontab -l | grep -c "eMerger/update.sh") -gt 0 ]]; then
    sudo crontab -u $USER -l | grep -v "eMerger/update.sh"  | sudo crontab -u $USER -
    printProgress "Cronjob successfully removed $SAD"
    exit 0
fi

# Initialize crontab
sudo crontab 2>/dev/null

# Add line to crontab
ROOT=${SRC::-3}
JOB="@reboot source ${ROOT}update.sh $ROOT 2>>$ROOT.errors"
( sudo crontab -u $USER -l; echo $JOB ) | sudo crontab -u $USER - 2>/dev/null
printf "${GREEN}Below you can see details about the crontab installed${BLUE}\n"
crontab -l | grep "eMerger/update.sh"
printf "${NORMAL}"
printProgress "Cronjob successfully installed $COOL"

exit 0
