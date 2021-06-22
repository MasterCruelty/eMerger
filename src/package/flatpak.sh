#!/bin/bash

PKG="flatpak"

printf "${GREEN}\nSystem detected: ${RED}Using $PKG${NORMAL}"

printProgress "flatpak update: starting"
sudo $PKG update
printProgress "flatpak update: completed"

printProgress "flatpak repair: starting"
sudo $PKG repair
printProgress "flatpak repair: completed"

printProgress "flatpak uninstall unused extensions: starting"
sudo $PKG uninstall --unused
printProgress "flatpak uninstall unused extensions: completed"
