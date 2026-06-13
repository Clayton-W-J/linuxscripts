#!/bin/bash
# =============================================================================
# Weekly Filesystem Check with Email Report
# =============================================================================
#
# Description:
#   This script performs a read-only filesystem check (fsck) on a specified
#   logical volume, logs the results, and sends an email report with the
#   findings. It is designed to be run periodically (e.g., weekly) as part
#   of a maintenance routine to ensure filesystem integrity.
#
#   The script will:
#   1. Unmount the target device if it is currently mounted
#   2. Run fsck in read-only mode (-n) with verbose output
#   3. Log the output to a designated log file
#   4. Remount the device after the check completes
#   5. Email the results to the configured recipient
#
# Requirements:
#   - Root privileges (required for mounting/unmounting and fsck)
#   - sendemail utility installed (apt-get install sendemail or equivalent)
#   - mountpoint command available
#
# Usage:
#   1. Configure the variables in the "Configuration" section below:
#      - SMTP_SERVER, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD
#      - FROM_EMAIL, TO_EMAIL
#      - DEVICE, MOUNT_POINT
#   2. Make the script executable: chmod +x weekly_fsck_report.sh
#   3. Run as root: sudo ./weekly_fsck_report.sh
#
# Notes:
#   - This script performs a READ-ONLY check (-n flag) and will NOT fix errors
#   - For automatic repair, remove the -n flag (use with caution!)
#   - Ensure adequate disk space for the log file
#   - Schedule with cron for automated weekly execution:
#     0 0 * * 0 /path/to/weekly_fsck_report.sh >> /var/log/cron_fsck.log 2>&1
#
# =============================================================================

# ==========================================
# Configuration
# ==========================================

SMTP_SERVER="smtp.example.com"
SMTP_PORT="587"
SMTP_USERNAME="your_email@example.com"
SMTP_PASSWORD="your_password"
FROM_NAME="My Server"
FROM_EMAIL="your_email@example.com"
TO_EMAIL="johndoe@example.com"

HOSTNAME=$(hostname)
DATE=$(date +"%m-%d-%Y %I:%M:%S %p")
LOG_FILE="/var/log/filesystem_check.log"
STATUS_FILE="/tmp/filesystem_check.txt"

# Device and mount point to check
DEVICE="/dev/mapper/vg--test-lv--test"
MOUNT_POINT="/mnt/test"

# Maximum lines to keep in the status file before truncation
MAX_LINES=50

# ==========================================
# Main Script
# ==========================================

# --- Run Filesystem Check ---
{
  echo "Weekly Filesystem Check Report for $HOSTNAME - $DATE"
  echo "=========================================="
  # Check if the device is mounted
  if mountpoint -q "$MOUNT_POINT"; then
    echo "Unmounting $DEVICE from $MOUNT_POINT..."
    umount "$DEVICE"
  fi
  # Run fsck in read-only mode with verbose output
  echo "Running fsck on $DEVICE..."
  fsck -n -f -V -C0 "$DEVICE"
  FSCK_EXIT_CODE=$?
  echo "fsck completed with exit code: $FSCK_EXIT_CODE"
  case $FSCK_EXIT_CODE in
    0) echo "Filesystem is clean, no errors found." ;;
    1) echo "Filesystem errors were corrected." ;;
    2) echo "Filesystem errors were detected but not corrected. Manual intervention required." ;;
    4) echo "Filesystem errors left uncorrected. Manual check is mandatory." ;;
    8) echo "Operational error. Check the device or system." ;;
    16) echo "Filesystem check was interrupted." ;;
    32) echo "Filesystem is unmounted, but could not complete the operation." ;;
    128) echo "Shared library error." ;;
    *) echo "An unknown error occurred during the fsck check." ;;
  esac
} | tee "$STATUS_FILE"

# --- Truncate if too large ---
if [ "$(wc -l < "$STATUS_FILE")" -gt "$MAX_LINES" ]; then
  tail -n "$MAX_LINES" "$STATUS_FILE" > "${STATUS_FILE}_trimmed"
  mv "${STATUS_FILE}_trimmed" "$STATUS_FILE"
fi

# --- Append to log file ---
cat "$STATUS_FILE" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"

# --- Remount device ---
mount "$DEVICE" "$MOUNT_POINT"

# --- Send Email with Results ---
echo "Sending email to $TO_EMAIL..."
# Read the status file as the email body
BODY=$(cat "$STATUS_FILE")

sendemail -v \
    -o tls=yes \
    -s "$SMTP_SERVER:$SMTP_PORT" \
    -f "$FROM_EMAIL" \
    -t "$TO_EMAIL" \
    -xu "$SMTP_USERNAME" \
    -xp "$SMTP_PASSWORD" \
    -u "Weekly Filesystem Check Report for $HOSTNAME - $DATE" \
    -m "$BODY"

if [ $? -eq 0 ]; then
    echo "Email sent successfully!"
else
    echo "Failed to send email."
fi

# --- Cleanup ---
rm -f "$STATUS_FILE"
echo "Check complete."
