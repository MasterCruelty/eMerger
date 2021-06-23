#!/bin/bash

src_path=$(dirname "$(readlink -f "$0")")
source "$src_path"/utils/global.sh

if [[ -f "$src_path/utils/.cache" ]]; then
	HASH=$(md5sum "$src_path/utils/.cache" | cut -d " " -f1)
	if [[ $HASH != $(cat $src_path/utils/.md5) ]]; then
		md5sum "$src_path"/utils/.cache | cut -d " " -f1 > "$src_path"/utils/.md5
	fi
else
    "$src_path"/utils/cachegen.sh > "$src_path"/utils/.cache
    md5sum "$src_path"/utils/.cache | cut -d " " -f1 > "$src_path"/utils/.md5
	chmod 775 "$src_path"/utils/.cache
fi
chmod 775 "$src_path"/utils/.md5

printf "${LOGO}"
if [[ $(stty size | awk '{print $2}') -ge 69 ]]; then
	cat "$src_path"/utils/.logo
fi
printf "Running on: $(uname -rs)\n${NORMAL}"

source "$src_path"/utils/privileges.sh
while read line; do
	if [[ "$line" != "" ]]; then
        source "$src_path"/"$line".sh;
    fi
done < $src_path/utils/.cache

exit 0
