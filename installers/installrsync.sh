#!/bin/bash
apt update
if [ ! -f /usr/bin/rsync ]; then
    sudo apt install -y rsync
fi
