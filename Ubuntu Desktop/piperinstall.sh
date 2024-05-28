#!/bin/bash
sudo add-apt-repository universe
sudo apt update
sudo apt install piper
sudo systemctl enable ratbagd.service
sudo systemctl daemon-reload
sudo systemctl reload dbus.service
sudo systemctl start ratbagd.service
