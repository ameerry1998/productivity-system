#!/bin/bash
# Script to learn and store home network gateway MACs

MACS_FILE="/usr/local/productivity/.home_gateway_macs"

# Get current gateway MAC
GW_IP=$(route -n get default 2>/dev/null | awk '/gateway/ {print $2; exit}')
if [ -z "$GW_IP" ]; then
    echo "❌ No gateway found"
    exit 1
fi

GW_MAC=$(arp -n "$GW_IP" 2>/dev/null | awk '{for(i=1;i<=NF;i++){if($i=="at"){print $(i+1); exit}}}')
if [ -z "$GW_MAC" ]; then
    echo "❌ Could not get gateway MAC"
    exit 1
fi

# Add to file if not already there
if [ -f "$MACS_FILE" ]; then
    if grep -qiF "$GW_MAC" "$MACS_FILE"; then
        echo "✅ Gateway MAC $GW_MAC already known"
    else
        echo "$GW_MAC" >> "$MACS_FILE"
        echo "✅ Added gateway MAC $GW_MAC to home network list"
    fi
else
    echo "$GW_MAC" > "$MACS_FILE"
    chmod 600 "$MACS_FILE"
    echo "✅ Created home network list with MAC $GW_MAC"
fi

echo ""
echo "Known home gateway MACs:"
cat "$MACS_FILE"
