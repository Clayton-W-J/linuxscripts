#!/bin/bash

# This script will re-run all of the default Ubuntu MOTD scripts that are used to build the MOTD present upon login. These scripts are located at /etc/update-motd.d/

# Clear the screen
clear

run-parts /etc/update-motd.d/
