#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="apt-get"


if [[ $(command -v apt) ]]; then
    PKG="apt"
    
	#These lines works on some systems only, for example I receive an error on a raspberry.
	#puts RED "configuration: starting"
	#try $PWR $PKG --configure -a
	#puts GREEN "configuration: completed"
	#puts RED "Error on --configure option"

    puts BLUE "Using $PKG $DEBIAN"

    puts RED "fix broken: starting"
    try $PWR $PKG --fix-broken install
    puts GREEN "fix broken: completed"

    puts RED "update: starting"
    try $PWR $PKG update
    puts GREEN "update: completed"

    puts RED "full-upgrade: starting"
    try $PWR $PKG full-upgrade
    puts GREEN "full-upgrade: completed"

    puts RED "autoremove: starting"
    try $PWR $PKG autoremove
    puts GREEN "autoremove: completed"

    puts RED "autoclean: starting"
    try $PWR $PKG autoclean
    puts GREEN "autoclean: completed"

    puts RED "clean: starting"
    try $PWR $PKG clean
    puts GREEN "clean: completed"
else
    puts BLUE "Using $PKG $DEBIAN"

    puts RED "update: starting"
    try $PWR $PKG update
    puts GREEN "update: completed"

    puts RED "dist-upgrade: starting"
    try $PWR $PKG dist-upgrade
    puts GREEN "dist-upgrade: completed"

    puts RED "autoremove: starting"
    try $PWR $PKG autoremove
    puts GREEN "autoremove: completed"

    puts RED "autoclean: starting"
    try $PWR $PKG autoclean
    puts GREEN "autoclean: completed"

    puts RED "clean: starting"
    try $PWR $PKG clean
    puts GREEN "clean: completed"
fi
