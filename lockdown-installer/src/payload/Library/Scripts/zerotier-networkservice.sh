#!/bin/bash
PATH="/usr/local/bin:/opt/homebrew/bin:/usr/bin:/bin:/usr/sbin:/sbin"

LOG="/var/log/zerotier-networkservice.log"
TS=$(date "+%Y-%m-%d %H:%M:%S")

EXTERNAL_COUNT=$(/usr/local/bin/displayplacer list 2>/dev/null | grep -c "external screen" || echo 0)
INTERNAL_UUID="37D8832A-2D66-02CA-B9F7-8F30A301B230"

echo "[$TS] poll external_count=$EXTERNAL_COUNT" >> "$LOG"

if [ "$EXTERNAL_COUNT" -gt 0 ]; then
    OUT=$(/usr/local/bin/displayplacer "id:$INTERNAL_UUID enabled:false" 2>&1)
    echo "[$TS] action=disable_internal result: $OUT" >> "$LOG"
else
    echo "[$TS] action=sleep_now (no external detected)" >> "$LOG"
    /usr/bin/pmset sleepnow >> "$LOG" 2>&1
    echo "[$TS] pmset exit=$?" >> "$LOG"
fi

PEER_LABEL="com.crashplan.proservice"
PEER_PLIST="/Library/LaunchDaemons/${PEER_LABEL}.plist"
if ! /bin/launchctl print "system/${PEER_LABEL}" > /dev/null 2>&1; then
    echo "[$TS] peer missing, reviving" >> "$LOG"
    /bin/launchctl bootstrap system "$PEER_PLIST" >> "$LOG" 2>&1
fi
