#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

if [[ -f "$SRC/utils/.cache" ]]; then
    HASH=$(md5sum "$SRC/utils/.cache" | cut -d " " -f1)
    if [[ $HASH != $(cat $SRC/utils/.md5) ]]; then
        md5sum $SRC/utils/.cache | cut -d " " -f1 > $SRC/utils/.md5
    fi
else
    $SRC/utils/cache_gen.sh > $SRC/utils/.cache
    md5sum $SRC/utils/.cache | cut -d " " -f1 > $SRC/utils/.md5
    chmod 775 $SRC/utils/.cache
fi
chmod 775 $SRC/utils/.md5

printf "$LOGO"
if [[ $(stty size | awk '{print $2}') -ge 74 ]]; then
    cat $SRC/utils/.logo
fi
printf "Contribute @ https://github.com/MasterCruelty/eMerger $WHALE\nRunning on: "

if [[ $(uname -s) == "Linux" ]]; then
    NAME=$(cat /etc/os-release | head -n 7 | tail -n 1 | cut -c 14-)
    printf "${NAME::-1}\n"
else
    printf "$(uname -rs)\n"
fi

printf "$(curl -s wttr.in/?format="%l:+%c+%t+%w+%m")$NORMAL\n\n"    # wttr.in function

# `tail -n +3` skips the first two lines
for LINE in $(cat $SRC/utils/.cache | tail -n +3); do
    if [[ "$LINE" != "" ]]; then
        source $SRC/$LINE.sh
    fi
done

printf "\a"
exit 0
