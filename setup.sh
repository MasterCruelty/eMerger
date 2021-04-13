#!/bin/bash

sed -i "4i cat $(pwd)/logo" $(pwd)/updater.sh
sed -i "5d" $(pwd)/updater.sh

EXST=$(cat ~/.bashrc | grep -c "updater.sh")
if [[ $EXST -ne 0 ]]; then
    exit 0
else
    echo "alias up='bash $(pwd)/updater.sh'" >> ~/.bashrc
    chmod +x updater.sh
fi