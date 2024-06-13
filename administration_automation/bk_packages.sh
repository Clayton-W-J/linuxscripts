# This script is currently a work in progress and is intended to be used to back up all apt packages on a linux machine and send it to a network location.

#!/bin/bash

# Defining destination of packages.list file
destination="/source/to/packages.list"

sudo apt update
sudo dpkg --get-selections > $destination
