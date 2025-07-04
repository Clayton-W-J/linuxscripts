#!/bin/bash

# Install the Proxmox Qemu Guest Agent
if [ ! -f /usr/sbin/qemu-ga ]; then
    read -p "Would you like to install the Proxmox QEMU Guest Agent? (y/n): " INSTALL_QEMU
    if [[ "$INSTALL_QEMU" =~ ^[Yy]$ ]]; then
        {
            echo "Installing, enabling, and starting the QEMU Guest Agent..."
            sudo apt install qemu-guest-agent -y
            sudo systemctl enable --now qemu-guest-agent
        } >> "$LOG_FILE" 2>&1
        echo "QEMU Guest Agent installed and enabled!"
    else
        echo "Skipping QEMU Guest Agent installation."
    fi
else
    echo "QEMU Guest Agent is already installed!"
fi
