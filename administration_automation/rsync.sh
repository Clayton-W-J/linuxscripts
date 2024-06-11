#!/bin/bash

# Defining source and destination
source="/home/cj/linuxscripts"
destination="/home/cj/testdir/"
log_file="/var/log/rsync_backup.log"

if [ ! -e "$source" ]; then
    echo "Error: Source path $source does not exist."
    exit 1
elif [ ! -d "$source" ] && [ ! -f "$source" ]; then
    echo "Error: Source path $source is neither a directory nor a file."
    exit 1
fi

# Check if the destination directory exists, create if not
if [ ! -d "$destination" ]; then
    echo "Destination directory $destination does not exist. Creating it..."
    mkdir -p "$destination"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create destination directory $destination."
        exit 1
    fi
fi

# rsync the source to the destination and log the output
echo "Starting rsync from $source to $destination at $(date)" | tee -a "$log_file"
sudo rsync -avzP "$source" "$destination" >> "$log_file" 2>&1
rsync_status=$?

# Check if rsync was successful
if [ $rsync_status -ne 0 ]; then
    echo "Error: rsync failed with status $rsync_status. Check the log file $log_file for details."
    exit 1
else
    echo "rsync completed successfully at $(date)." | tee -a "$log_file"
fi
