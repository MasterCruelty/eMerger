#!/bin/bash
echo -e "apt-get update: starting\n"
sudo apt-get update
echo -e "apt-get update: done\n"
sleep 1
echo -e "apt-get upgrade: starting\n"
sudo apt-get upgrade
echo -e "apt-get upgrade: done\n"
sleep 1
echo -e "autoclean: starting\n"
sudo apt-get autoclean #this command deletes useless files so the cache will be clean.
echo -e "autoclean: done\n"
sleep 1
echo -e "autoremove: starting\n"
sudo apt-get autoremove #this command deletes dependencies that now are useless.
echo -e "autoremove: done\n"
