#/bin/bash

# This is a very sloppy script to wrap up my automated VM deployment on Proxmox

# -------------------------------
# Manually defined variables Start
# -------------------------------

NEW_HOSTNAME=""   # Set New Hostname

# -------------------------------
# Manually defined variables End
# -------------------------------

# Regenerate Host Keys due to template having them removed
sudo /usr/bin/ssh-keygen -A
sudo systemctl restart sshd

# Set the hostname
echo "Setting hostname to $NEW_HOSTNAME..."
sudo hostnamectl set-hostname "$NEW_HOSTNAME"
# Update /etc/hosts
echo "Updating /etc/hosts file..."
sudo sed -i "s/127.0.1.1.*/127.0.1.1\t$NEW_HOSTNAME/g" /etc/hosts
