#!/bin/bash

SRC=$(dirname "$(readlink -f "$0")")
source $SRC/utils/global.sh

PWR=$(source $SRC/utils/check_pwr.sh)
PKG="nixos-rebuild switch"

puts BLUE "Using $PKG $NIX"

puts RED "upgrade: starting"
try $PWR nix-channel --update
puts GREEN "upgrade: completed"

puts RED "upgrade: starting"
try $PWR $PKG --upgrade
puts GREEN "upgrade: completed"

puts RED "repair: starting"
try $PWR $PKG --repair
puts GREEN "repair: completed"

puts RED "repair: starting"
try $PWR nix-collect-garbage -d
puts GREEN "repair: completed"
