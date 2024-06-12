# This script is intended to be used to back all apt packages on a linux machine using apt and send it to a network location.

#!/bin/bash

# Install dselect if it's not already present
if [ ! -f /usr/bin/dselect ]; then
    sudo apt install -y dselect
fi

# Vars
destination="/home/cj/packages.list"

sudo apt update
sudo dpkg --get-selections > $destination