#!/bin/bash

# Optimized SSID scanner with caching
# This dramatically speeds up network detection

CACHE_FILE="/tmp/.ssid_cache"
CACHE_MAX_AGE=10  # Cache valid for 10 seconds

# Check if cache is fresh
if [ -f "$CACHE_FILE" ]; then
    cache_age=$(($(date +%s) - $(stat -f %m "$CACHE_FILE" 2>/dev/null || echo 0)))
    if [ $cache_age -lt $CACHE_MAX_AGE ]; then
        # Cache is fresh, use it
        cat "$CACHE_FILE"
        exit 0
    fi
fi

# Cache miss or stale - scan networks
networks=$(/usr/bin/swift - 2>/dev/null <<'SWIFT'
import Foundation
import CoreWLAN

let client = CWWiFiClient.shared()
guard let iface = client.interface() else { exit(1) }
do {
    let networks = try iface.scanForNetworks(withSSID: nil)
    let ssids = Set(networks.compactMap { $0.ssid }.filter { !$0.isEmpty })
    for s in ssids.sorted() { print(s) }
} catch { exit(2) }
SWIFT
)

# Store in cache if successful
if [ -n "$networks" ]; then
    echo "$networks" > "$CACHE_FILE"
    echo "$networks"
    exit 0
else
    # Scan failed - use stale cache if available
    if [ -f "$CACHE_FILE" ]; then
        cat "$CACHE_FILE"
        exit 0
    fi
    exit 1
fi

