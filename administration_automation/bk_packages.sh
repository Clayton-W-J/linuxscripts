# This script is intended to be used to back up all apt packages on a linux machine and send it to a network location.

#!/bin/bash

# Install dselect if it's not already present
if [ ! -f /usr/bin/dselect ]; then
    sudo apt install -y dselect
fi

# Defining destination of packages.list file
destination="/source/to/packages.list"

sudo apt update
sudo dpkg --get-selections > $destination
