#!/bin/bash
# Piper is a GTK+ application to configure gaming mice and keyboard. More info can be found here: https://github.com/libratbag/piper
sudo add-apt-repository universe
sudo apt update
sudo apt install piper
sudo systemctl enable ratbagd.service
sudo systemctl daemon-reload
sudo systemctl reload dbus.service
sudo systemctl start ratbagd.service
