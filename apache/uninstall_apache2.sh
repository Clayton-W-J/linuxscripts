#!/bin/bash
clear
echo "1. Uninstall Apache2 (Removes just the Apache package)"
echo "2. Purge Apache2 (Removes Apache and all config files)"
echo "3. Quit"
echo "Please select 1, 2, or 3."

read -n 1 user_input

if [ $user_input == 1 ]; then
    clear
    sudo apt remove apache2
fi

if [ $user_input == 2 ]; then
    clear
    sudo apt purge -y apache2
    sudo apt purge -y apache2-bin libapache2-mod-php8.1
    sudo apt autoremove -y
fi

if [ $user_input == 3 ]; then
    clear
fi
