#!/bin/bash

# Piper is a GTK+ application to configure gaming mice and keyboard. This bash script is designed to install Piper. More info can be found here: https://github.com/libratbag/piper
sudo add-apt-repository universe
sudo apt update
sudo apt install piper
sudo systemctl enable ratbagd.service
sudo systemctl daemon-reload
sudo systemctl reload dbus.service
sudo systemctl start ratbagd.service
