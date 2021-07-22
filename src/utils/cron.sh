#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

if [[ $(grep -c "utils/privileges" $(dirname "$(readlink -f "$0")")/utils/.cache) -lt 1 ]]; then
    put RED "Sorry, but this command can't be executed without sudo privileges $MONOCLE"
    exit 1
fi

if [[ ! $(command -v crontab) ]]; then
    put RED "Package crontab is required.\nInstall it and repeat the command"
    exit 1
fi

if [[ $(crontab -l | grep -c "eMerger/update.sh") -gt 0 ]]; then
    sudo crontab -u $USER -l | grep -v "eMerger/update.sh"  | sudo crontab -u $USER -
    put GREEN "Cronjob successfully removed $SAD"
    exit 0
fi

put RED "If you never initialized the crontab, you may need to press CTRL+C or any SIGINT equivalent"
# Initialize crontab
sudo crontab 2>/dev/null

ROOT=${SRC::-3}

# Keeping track of exact time
date "+%D %T:%N" >> $ROOT.log

# Add line to crontab
JOB="@reboot source ${ROOT}update.sh $ROOT"
( sudo crontab -u $USER -l; echo $JOB ) | sudo crontab -u $USER - 2>/dev/null

# Find the content and print it line by line
# NR stands for Number of Records in input
# RS defines how records are separated
# <<< is the `Here Strings` redirection from the GNU bash manual
put GREEN "\nDetails about your installed cronjob $SCROLL"
put LOGO "(\n$(awk 'NR>0' RS=' ' <<< $(crontab -l | grep "eMerger/update.sh"))\n)"

put GREEN "\nCronjob successfully installed $COOL"

exit 0
