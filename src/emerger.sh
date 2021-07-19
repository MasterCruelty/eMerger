#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
ROOT=${SRC::-3}
source $SRC/utils/global.sh

ARGC=$#
ARGV=$@

# Check if arguments passed exist
if [[ $ARGC -gt 0 ]]; then
    source $SRC/test/argument_check.sh $ARGV
fi

if [[ $ARGV =~ "-help" ]]; then
    cat $SRC/utils/help
elif [[ $ARGV =~ "-au" ]]; then
    source $SRC/utils/cron.sh
elif [[ $ARGV =~ "-err" ]]; then
    if [[ $(grep -v "[0-9]*:[0-9]*:[0-9]*:[0-9]*" $ROOT.log | wc -l) -gt 0 ]]; then
        put RED "Errors found\nOpen .log to see what's wrong"
    else
        put GREEN "No errors found"
    fi
elif [[ $ARGV =~ "-up" ]]; then
    source $ROOT/update.sh $ROOT
elif [[ $ARGV =~ "-xyzzy" ]]; then
    put NC "Let's keep its memory alive"
else
    if [[ -f "$SRC/utils/.cache" && ! $ARGV =~ "-rc" ]]; then
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

    # Logo
    if [[ ! $ARGV =~ "-nl" ]]; then
        if [[ $(stty size | awk '{print $2}') -ge 74 ]]; then
            put LOGO "$(cat $SRC/utils/.logo)"
        fi
        put LOGO "Contribute @ https://github.com/MasterCruelty/eMerger $WHALE"
    fi

    # System informations
    if [[ ! $ARGV =~ "-ni" ]]; then
        if [[ -f "/etc/os-release" ]]; then
            NAME=$(cat /etc/os-release | head -n $(echo $(grep -n "PRETTY_NAME" /etc/os-release) | cut -c 1) | tail -n 1 | cut -c 14-)
            put LOGO "${NAME::-1}"
        else
            put LOGO "$(uname -rs)"
        fi
    fi

    # Weather
    if [[ $ARGV =~ "-w" ]]; then
        # Using wttr.in to show the weather using the following arguments:
        # %l = location; %c = weather emoji; %t = actual temp; %w = wind km/h; %m = Moon phase
        put LOGO "$(curl -s wttr.in/?format="%l:+%c+%t+%w+%m")"
    fi

    # `tail -n +3` skips the first two lines
    for LINE in $(cat $SRC/utils/.cache | tail -n +3); do
        if [[ $LINE == "utils/trash" && $ARGV =~ "-nt" ]]; then
            continue
        fi

        if [[ $LINE != "" ]]; then
            source $SRC/$LINE.sh
            put NC ""
        fi
    done

    # Notify if errors are present
    if [[ $(grep -v "[0-9]*:[0-9]*:[0-9]*:[0-9]*" $ROOT.log | wc -l) -gt 0 ]]; then
        put LOGO "\n\nSomething is not working correctly, type \"up -err\" for further informations"
    fi

    printf "\a"
fi

exit 0
