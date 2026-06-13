#!/bin/bash
# =============================================================================
# Weekly mdadm RAID Health Check with Email Report
# =============================================================================
#
# Description:
#   This script performs a read-only RAID consistency check (mdadm scrub)
#   on a specified RAID array, logs the results, and sends an email report
#   with the findings. It is designed to be run periodically (e.g., weekly)
#   as part of a maintenance routine to ensure RAID integrity.
#
#   The script will:
#   1. Run a read-only consistency check on the specified array
#   2. Wait for the check to complete
#   3. Log the results and check for mismatches
#   4. Email the results to the configured recipient
#
# Requirements:
#   - Root privileges (required for mdadm operations)
#   - sendemail utility installed (apt-get install sendemail or equivalent)
#   - mdadm utility installed
#
# Usage:
#   1. Configure the variables in the "Configuration" section below:
#      - SMTP_SERVER, SMTP_PORT, SMTP_USERNAME, SMTP_PASSWORD
#      - FROM_EMAIL, TO_EMAIL
#      - ARRAY_DEVICE (the RAID array to check)
#   2. Make the script executable: chmod +x weekly_mdadm_check.sh
#   3. Run as root: sudo ./weekly_mdadm_check.sh
#
# Notes:
#   - This script performs a READ-ONLY check and will NOT fix errors
#   - For automatic repair, use "repair" instead of "check" (use with caution!)
#   - To run repair only when mismatches are found, modify the script logic
#   - Schedule with cron for automated weekly execution:
#     0 2 * * 0 /path/to/weekly_mdadm_check.sh >> /var/log/cron_mdadm.log 2>&1
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
LOG_FILE="/var/log/mdadm_health_check.log"
STATUS_FILE="/tmp/mdadm_health_check.txt"
# RAID array to check (e.g., "md0", "md1", "md/home")
# Leave empty to check all arrays, or specify one array
ARRAY_DEVICE="mdX"
# Maximum lines to keep in the status file before truncation
MAX_LINES=100
# ==========================================
# Main Script
# ==========================================
# --- Run RAID Health Check ---
{
  echo "Weekly mdadm RAID Health Check Report for $HOSTNAME - $DATE"
  echo "=========================================="
  # Determine which array(s) to check
  if [ -z "$ARRAY_DEVICE" ]; then
    # Check all arrays
    ARRAY_LIST=$(cat /proc/mdstat | grep "^md" | awk '{print $1}')
    if [ -z "$ARRAY_LIST" ]; then
      echo "No RAID arrays found!"
    else
      echo "Checking all arrays: $ARRAY_LIST"
    fi
  else
    # Check specified array
    ARRAY_LIST="$ARRAY_DEVICE"
    echo "Checking specified array: $ARRAY_DEVICE"
  fi
  echo ""
  # Loop through each array
  for ARRAY in $ARRAY_LIST; do
    echo "--- Checking $ARRAY ---"
    # Verify the array exists
    if [ ! -f "/sys/block/$ARRAY/md/sync_action" ]; then
      echo "ERROR: Array $ARRAY does not exist!"
      continue
    fi
    # Trigger read-only check
    echo "Starting read-only consistency check on $ARRAY..."
    echo check > "/sys/block/$ARRAY/md/sync_action"
    # Wait for check to complete
    echo "Waiting for check to complete..."
    while grep -q "check" "/sys/block/$ARRAY/md/sync_action" 2>/dev/null; do
      sleep 10
    done
    echo "Check completed."
    echo ""
    # Get array status
    cat "/proc/mdstat" | sed -n "/^$ARRAY/,/^$/p"
    echo ""
  done
  # Check for mismatches
  echo "=========================================="
  echo "Mismatch Summary"
  echo "=========================================="
  if [ -z "$ARRAY_LIST" ]; then
    echo "No arrays to check."
    SUBJECT="RAID Health Check - ERROR"
  else
    MISMATCHES=$(grep -r "mismatch_cnt" /sys/block/md*/md/ 2>/dev/null | grep -v ":0$")
    if [ -z "$MISMATCHES" ]; then
      echo "All checks passed - 0 mismatches found."
      SUBJECT="RAID Health Check - OK"
    else
      echo "WARNING: Mismatches detected!"
      echo "$MISMATCHES"
      SUBJECT="RAID Health Check - WARNING"
    fi
  fi
  echo ""
  echo "Completed at: $(date +'%m-%d-%Y %I:%M:%S %p')"
} | tee "$STATUS_FILE"
# --- Truncate if too large ---
if [ "$(wc -l < "$STATUS_FILE")" -gt "$MAX_LINES" ]; then
  tail -n "$MAX_LINES" "$STATUS_FILE" > "${STATUS_FILE}_trimmed"
  mv "${STATUS_FILE}_trimmed" "$STATUS_FILE"
fi
# --- Append to log file ---
cat "$STATUS_FILE" >> "$LOG_FILE"
echo "" >> "$LOG_FILE"
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
    -u "Weekly mdadm RAID Health Check Report for $HOSTNAME - $DATE" \
    -m "$BODY"
if [ $? -eq 0 ]; then
    echo "Email sent successfully!"
else
    echo "Failed to send email."
fi
# --- Cleanup ---
rm -f "$STATUS_FILE"
echo "Check complete."
