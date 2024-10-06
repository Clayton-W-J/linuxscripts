#!/bin/bash
apt update
if [ ! -f /usr/bin/rsync ]; then
    sudo apt install -y rsync
else
echo "rsync is already installed!"
fi
