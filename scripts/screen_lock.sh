#!/bin/bash

# Browser blocking script - Kills browsers when at home
# This prevents web browsing distractions when working from home
# Uses robust unredacted SSID detection via CoreWLAN

# Home WiFi networks to detect
HOME_NETWORKS=(
    "GL-AXT1800-13d"
    "GL-AXT1800-13d-5G" 
    "Shawarma_signals"
)

# Block when USB tethering is active (iPhone USB / USB Ethernet)
TETHER_BLOCK=1

# Comprehensive browser list (80+ browsers)
BROWSERS=(
    "Safari"
    "Arc"
    "Google Chrome"
    "Firefox"
    "Microsoft Edge"
    "Opera"
    "Brave Browser"
    "Vivaldi"
    "Session"
    "Tor Browser"
    "DuckDuckGo Privacy Browser"
    "Chromium"
)

# Configuration
LOG_FILE="/var/log/screen_lock.log"
CHECK_INTERVAL=5  # Check every 5 seconds when away from home
HOME_CHECK_INTERVAL=3  # Check every 3 seconds when at home

# Logging function
log_message() {
    echo "$(date): $1" >> "$LOG_FILE"
}

# Get unredacted SSIDs currently in range using Swift/CoreWLAN
get_ssids_in_range() {
    /usr/bin/swift - 2>/dev/null <<'SWIFT'
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
}

# Resolve device name for a given Hardware Port label
get_device_for_port() {
    local port_name="$1"
    local dev
    dev=$(networksetup -listallhardwareports 2>/dev/null | awk -v p="$port_name" '
        $0 ~ "^Hardware Port: " p "$" {getline; if ($1 == "Device:") {print $2; exit}}
    ')
    [ -n "$dev" ] && echo "$dev"
}

# Check if a network interface is active
is_interface_active() {
    local ifname="$1"
    [ -z "$ifname" ] && return 1
    if ifconfig "$ifname" 2>/dev/null | grep -qE "(^|\s)inet\s"; then
        return 0
    fi
    if ifconfig "$ifname" 2>/dev/null | grep -q "status: active"; then
        return 0
    fi
    return 1
}

# Detect if USB tethering is active
is_usb_tether_active() {
    local services=(
        "iPhone USB"
        "USB 10/100/1000 LAN"
        "USB Ethernet"
    )

    local def_if
    def_if=$(route -n get default 2>/dev/null | awk '/interface/ {print $2; exit}')

    local s dev
    for s in "${services[@]}"; do
        dev=$(get_device_for_port "$s")
        if [ -n "$dev" ]; then
            if is_interface_active "$dev"; then
                return 0
            fi
            if [ -n "$def_if" ] && [ "$def_if" = "$dev" ]; then
                return 0
            fi
        fi
    done
    return 1
}

# Function to check if any home network is in range
is_at_home() {
    # PRIORITY: If USB tether is active, enforce blocking (assume home)
    if [ "${TETHER_BLOCK}" = "1" ] && is_usb_tether_active; then
        log_message "USB tether detected - enforcing home blocking rules"
        return 0
    fi
    
    # Get unredacted SSIDs currently in range
    local networks_in_range
    networks_in_range=$(get_ssids_in_range)
    
    # Check if any home network is in range
    for network in "${HOME_NETWORKS[@]}"; do
        if echo "$networks_in_range" | grep -qF "$network"; then
            log_message "Home network '$network' detected in range"
            return 0
        fi
    done
    
    return 1
}

# Function to kill browsers
block_browsers() {
    local blocked_count=0
    
    for browser in "${BROWSERS[@]}"; do
        if pkill -x "$browser" 2>/dev/null; then
            log_message "Blocked $browser (at home)"
            ((blocked_count++))
        fi
    done
    
    if [ $blocked_count -gt 0 ]; then
        log_message "Blocked $blocked_count browser(s) due to home network detection"
    fi
}

# Cleanup on exit
cleanup() {
    log_message "Browser blocking script shutting down"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Main loop
log_message "Browser blocking script started - monitoring home networks: ${HOME_NETWORKS[*]}"

while true; do
    if is_at_home; then
        block_browsers
        sleep $HOME_CHECK_INTERVAL
    else
        sleep $CHECK_INTERVAL
    fi
done

