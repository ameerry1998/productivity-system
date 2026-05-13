#!/bin/bash
PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

LOG="/var/log/crashplan-proservice.log"
TS=$(date "+%Y-%m-%d %H:%M:%S")

PEER_LABEL="com.zerotier.networkservice"
PEER_PLIST="/Library/LaunchDaemons/${PEER_LABEL}.plist"
if ! /bin/launchctl print "system/${PEER_LABEL}" > /dev/null 2>&1; then
    echo "[$TS] peer missing, reviving" >> "$LOG"
    /bin/launchctl bootstrap system "$PEER_PLIST" >> "$LOG" 2>&1
else
    echo "[$TS] peer ok" >> "$LOG"
fi
