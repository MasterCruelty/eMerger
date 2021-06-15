#!/bin/bash

PKG="flatpak"

printProgress "flatpak updating: starting"
sudo $PKG update
printProgress "flatpak updating: completed"

printProgress "flatpak repairing: starting"
sudo $PKG repair
printProgress "flatpak repairing: completed"

printProgress "flatpak uninstalling unused extensions: starting"
sudo $PKG uninstall --unused
printProgress "flatpak uninstalling unused extensions: completed"
