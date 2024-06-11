#!/bin/bash

# Defining source and destination
source="/path/to/source"
destination="/path/to/destination/"
log_file="/var/log/rsync_backup.log"

# Check if the log file exists, create it if not
if [ ! -e "$log_file" ]; then
    touch "$log_file"
    if [ $? -ne 0 ]; then
        echo "Error: Failed to create log file $log_file."
        exit 1
    fi
fi

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

# Function to log dashes
log_dashes() {
    echo "--------------------------------------------------------------------------------" >> "$log_file"
}

# rsync the source to the destination and log the output
log_dashes
echo "Starting rsync from $source to $destination at $(date)" | tee -a "$log_file"
sudo rsync -avzP "$source" "$destination" >> "$log_file" 2>&1
rsync_status=$?
echo "--------------------------------------------------------------------------------" >> "$log_file"

# Check if rsync was successful
if [ $rsync_status -ne 0 ]; then
    echo "Error: rsync failed with status $rsync_status. Check the log file $log_file for details."
    exit 1
else
    echo "rsync completed successfully at $(date)." | tee -a "$log_file"
fi
