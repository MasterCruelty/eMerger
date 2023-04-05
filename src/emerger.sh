#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
ROOT=${SRC::-3}
source $SRC/utils/global.sh

# Create .log if it doesn't exist
if [[ ! -f $ROOT.log ]]; then
    printf "" > $ROOT.log
fi

# Clear .log if it gets too long (keep only the last 256 lines)
# Given no errors, the max file size is 7KB
if [[ $(wc -l < $ROOT.log) -gt 256 ]]; then
    printf "$(tail -n 256 $ROOT.log)\n" > $ROOT.log
fi

# If the script got interrupted, history still exists and has to be cleaned
echo -n "" > $SRC/.hist

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
    if [[ $(grep -cv "[0-9]*/[0-9]*/[0-9]* [0-9]*:[0-9]*:[0-9]*:[0-9]*" $ROOT.log) -gt 0 ]]; then
        puts RED "Errors found\nOpen .log in $ROOT to see what's wrong"
    else
        puts GREEN "No errors found"
    fi
elif [[ $ARGV =~ "-up" ]]; then
    source ${ROOT}update.sh $ROOT
elif [[ $ARGV =~ "-xyzzy" ]]; then
    puts NC "Let's keep its memory alive"
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
            puts LOGO "$(cat $SRC/utils/.logo)"
            echo "$NORMAL$LOGO$(cat $SRC/utils/.logo)$NORMAL\n" >> $SRC/.hist
        fi
        puts LOGO "Contribute @ https://github.com/MasterCruelty/eMerger $WHALE"

    fi

    # System informations
    if [[ ! $ARGV =~ "-ni" ]]; then
        if [[ -f "/etc/os-release" ]]; then
            NAME=$(cat /etc/os-release | head -n $(echo $(grep -n "PRETTY_NAME" /etc/os-release) | cut -c 1) | tail -n 1 | cut -c 13-)
            puts LOGO "${NAME}"
        else
            puts LOGO "$(uname -rs)"
        fi
    fi

    # Weather
    if [[ $ARGV =~ "-w" ]]; then
        # Using wttr.in to show the weather using the following arguments:
        # %l = location; %c = weather emoji; %t = actual temp; %w = wind km/h; %m = Moon phase
        puts LOGO "$(curl -s wttr.in/?format="%l:+%c+%t+%w+%m")"
    fi

    # `tail -n +3` skips the first two lines
    # ITER keeps track of iterations ('tail -n 3', so ITER='3-1')
    ITER=2
    for LINE in $(cat $SRC/utils/.cache | tail -n +3); do
        ITER=$(($ITER + 1))
        if [[ $LINE == "utils/cache" && $ARGV =~ "-nc" ]]; then
            continue
        fi

        if [[ $LINE == "utils/trash" && $ARGV =~ "-nt" ]]; then
            continue
        fi

        if [[ $LINE != "" ]]; then
            source $SRC/$LINE.sh
            if [[ $LINE != "utils/privileges" ]]; then
                echo "$BLUE$PKG COMPLETED$NORMAL\n" >> $SRC/.hist
            fi
        fi

        if [[ $ITER != $(cat $SRC/utils/.cache | wc -l) ]]; then
            puts NC ""
        fi
    done

    # Notify if errors are present
    if [[ $(grep -v "[0-9]*:[0-9]*:[0-9]*:[0-9]*" $ROOT.log | wc -l) -gt 0 ]]; then
        puts LOGO "\n\nSomething is not working correctly, type \"up -err\" for further informations\a"
    fi

    echo -ne "${BLUE}eMerger COMPLETED$NORMAL\n"
fi

rm $SRC/.hist

exit 0
