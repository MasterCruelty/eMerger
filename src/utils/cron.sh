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

printf "${RED}If you never initialized the crontab, you may need to press CTRL+C or any SIGINT equivalent${NORMAL}\n"
# Initialize crontab
sudo crontab 2>/dev/null

# Add line to crontab
ROOT=${SRC::-3}
JOB="@reboot source ${ROOT}update.sh $ROOT 2>>$ROOT.errors"
( sudo crontab -u $USER -l; echo $JOB ) | sudo crontab -u $USER - 2>/dev/null

# Find the content and print it line by line
# NR stands for Number of Records in input
# RS defines how records are separated
# <<< is the `Here Strings` redirection from the GNU bash manual
printProgress "\nDetails about your installed cronjob $SCROLL"
printf "${LOGO}(\n$(awk 'NR>0' RS=' ' <<< $(crontab -l | grep "eMerger/update.sh"))\n)${NORMAL}\n"

printProgress "\nCronjob successfully installed $COOL"

exit 0
