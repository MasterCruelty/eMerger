#!/bin/bash

osVersion=$(sw_vers -productVersion)

installerPath=""
# Extract major and minor version numbers
majorVersion=$(echo $macOSVersion | cut -d '.' -f 1)
minorVersion=$(echo $macOSVersion | cut -d '.' -f 2)

# Check which version is installed
if [ $majorVersion == "11" ]; then
    installerPath="Install macOS Big Sur.app"
elif [ $majorVersion == "12" ]; then
    installerPath="Install macOS Monterey.app"
elif [ $majorVersion == "13" ]; then
    installerPath="Install macOS Ventura.app"
elif [ $majorVersion == "14" ]; then
    installerPath="Install macOS Sonoma.app"
else
    echo "Unsupported MacOS version."
    exit 1
fi

# Get full path
fullPath="/Applications/$installerPath/Contents/Resources/startosinstall"

# Command which updates system
softwareupdate --fetch-full-installer –full-installer-version $osVersion
echo "Insert password:"
# Get privileges
sudo "$fullPath" --agreetolicense --forcequitapps --nointeraction --user "$USER"
