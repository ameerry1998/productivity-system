#!/bin/bash

# Fast network scanner - NO CACHE
# Always returns real-time results (~0.2 seconds)
# Simple, reliable, accurate - no stale data
# FAIL-CLOSED: If Swift fails, return special marker (assume home)

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

# Check if scan succeeded
if [ $? -ne 0 ] || [ -z "$networks" ]; then
    # Swift compilation or scan failed - FAIL CLOSED (assume home for safety)
    echo "SWIFT_COMPILATION_FAILED_ASSUME_HOME"
    exit 1
fi

echo "$networks"
exit 0
