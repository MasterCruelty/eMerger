#!/bin/bash

source src/other/global.sh
printProgress "Setup: starting"

cp -f $(pwd)/src/other/.logo ~/.logo

EXST=$(cat ~/.bashrc | grep -c "updater.sh")
if [[ $EXST -ne 0 ]]; then
   
	printProgress "Alias 'up' already exists. Use 'up' or run './src/updater.sh'."
	printProgress "Setup completed"
    exit 0
else
    echo "alias up='bash $(pwd)/src/updater.sh'" >> ~/.bashrc
    chmod +x src/updater.sh
    printProgress "Alias 'up' added.\nUse 'up' or run './src/updater.sh'."
    printProgress "Setup completed."
fi
printf "${RED}"
read -p "Press enter, the process will be killed:\nif your terminal closes, open a new one to see changes." text
printf "${NORMAL}"

kill -9 $PPID
exit 0
