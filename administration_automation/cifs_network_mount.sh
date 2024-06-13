# This script is intended to be a quick and easy way of mounting a cifs file share. The file share will be mounted using the current user's uid and gid.
# Version 3.0 of smb is in use here. This may need to be changed based on what version your machines run.

#!/bin/bash

# Function to prompt for user input
prompt() {
    local prompt_text="$1"
    local var_name="$2"
    read -p "$prompt_text" $var_name
}

# Prompt user for network share details
prompt "Enter the network share (e.g., //server/share): " network_share
prompt "Enter the mount point (e.g., /mnt/share): " mount_point
prompt "Enter your username: " username
echo -n "Enter your password: "
read -s password
echo

# Create mount point directory if it does not exist
if [ ! -d "$mount_point" ]; then
    mkdir -p "$mount_point"
fi

# Mount the network share with current user and group id's
mount_options="username=$username,password=$password,vers=3.0,uid=$(id -u),gid=$(id -g)"
sudo mount -t cifs "$network_share" "$mount_point" -o "$mount_options"

# If needing mount the share using root priviledges comment out the above variables and command, then un-comment the below command:
#sudo mount -t cifs "$network_share" "$mount_point" -o username="$username",password="$password",vers=3.0

# Check if the mount was successful
if [ $? -eq 0 ]; then
    echo "Successfully mounted $network_share to $mount_point"
else
    echo "Failed to mount $network_share"
fi
