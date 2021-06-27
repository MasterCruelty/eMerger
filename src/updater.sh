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
if [[ $(stty size | awk '{print $2}') -ge 69 ]]; then
    cat $SRC/utils/.logo
fi
printf "Running on: $(uname -rs)\n\n$NORMAL"

# `tail -n +2` skips the first line
for LINE in $(cat $SRC/utils/.cache | tail -n +2); do
    if [[ "$LINE" != "" ]]; then
        source $SRC/$LINE.sh
    fi
done

printf "\a"
exit 0
