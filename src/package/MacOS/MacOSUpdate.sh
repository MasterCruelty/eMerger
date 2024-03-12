#!/bin/bash
#Fetch MacOS version
osVersion=$(sw_vers -productVersion)

installerPath=""
#Get major and minor version
majorVersion=$(echo $osVersion | cut -d "." -f 1)
minorVersion=$(echo $osVersion | cut -d "." -f 2)

#Check which version is installed
if [ $majorVersion == "12" ];then
    installerPath="install macOS Monterey.app"
elif [ $majorVersion == "11" ];then
    installerPath="Install macOS Big Sur.app"
elif [ $minorVersion == "15"* ];then
    installerPath="Install macOS Catalina.app"
elif
    echo "Unsupported MacOS version."
    exit 1
fi

#get full path
fullPath="/Applications/$installerPath/Contents/Resources/startosinstall"

#command which updates system
softwareupdate --fetch-full-installer –full-installer-version $osVersion
echo "Inserire la password:"
sudo "$fullPath" --agreetolicense --forcequitapps --nointeraction --user "$USER"
