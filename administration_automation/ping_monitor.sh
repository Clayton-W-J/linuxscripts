# To run this script in the shell terminal: ./ping_monitor.sh <ipaddress>
# To run this script in the background: nohup ./ping_monitor.sh <ipaddress> >/dev/null 2>&1 &
# To stop the script: pkill -f ping_monitor.sh

#!/bin/bash

TARGET="$1"
LOGFILE="/var/log/ping_monitor.log"

# Check usage
if [ -z "$TARGET" ]; then
  echo "Usage: $0 <host-or-ip>"
  exit 1
fi

# Ensure log directory exists
mkdir -p "$(dirname "$LOGFILE")"

echo "=== Starting ping monitor for $TARGET at $(date) ===" | tee -a "$LOGFILE"

while true; do
  TIMESTAMP="$(date '+%Y-%m-%d %H:%M:%S')"
  
  if ping -c 1 -W 2 "$TARGET" > /dev/null 2>&1; then
    echo "[$TIMESTAMP] OK: $TARGET is reachable" | tee -a "$LOGFILE"
  else
    echo "[$TIMESTAMP] FAIL: $TARGET is NOT reachable" | tee -a "$LOGFILE"
  fi

  sleep 5
done
