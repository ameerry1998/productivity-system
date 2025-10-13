#!/bin/bash

# Home Usage Limiter - Locks laptop after 4 hours of cumulative use at home
# Tracks time spent at home and enforces hard screen lock with password requirement

SCRIPT_NAME="HOME_LIMITER"

# Configuration
DAILY_HOME_LIMIT=14400  # 4 hours in seconds
TIMER_FILE="/var/log/home_usage.timer"
LOG_FILE="/var/log/home_usage.log"
CHECK_INTERVAL=30  # Check every 30 seconds

# Notification tracking files
NOTIFIED_2H="/tmp/.home_notified_2h"
NOTIFIED_1H="/tmp/.home_notified_1h"
NOTIFIED_30M="/tmp/.home_notified_30m"
NOTIFIED_10M="/tmp/.home_notified_10m"

# Home WiFi networks to detect (same as screen_lock.sh)
HOME_NETWORKS=(
    "GL-AXT1800-13d"
    "GL-AXT1800-13d-5G" 
    "Shawarma_signals"
)

# Block when USB tethering is active
TETHER_BLOCK=1

# Unified logging function with script name prefix
log_message() {
    echo "[$SCRIPT_NAME] $(date '+%Y-%m-%d %H:%M:%S'): $1" | tee -a "$LOG_FILE"
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
        return 0
    fi
    
    # Get unredacted SSIDs currently in range
    local networks_in_range
    networks_in_range=$(get_ssids_in_range)
    
    # FAIL-CLOSED: If Swift failed, assume home for safety
    if echo "$networks_in_range" | grep -qF "SWIFT_COMPILATION_FAILED_ASSUME_HOME"; then
        log_message "⚠️  Network scanner failed - ASSUMING HOME (fail-closed for safety)"
        return 0
    fi

    # Check if any home network is in range
    for network in "${HOME_NETWORKS[@]}"; do
        if echo "$networks_in_range" | grep -qF "$network"; then
            return 0
        fi
    done
    
    return 1
}

# Get current day
get_current_day() {
    date +%Y-%m-%d
}

# Get today's home usage time
get_today_usage() {
    local today=$(get_current_day)
    if [ -f "$TIMER_FILE" ]; then
        grep "^$today:" "$TIMER_FILE" | cut -d: -f2 2>/dev/null || echo "0"
    else
        echo "0"
    fi
}

# Update usage counter
update_usage() {
    local today=$(get_current_day)
    local interval=$CHECK_INTERVAL
    
    # Get current usage
    local current_usage=$(get_today_usage)
    local new_usage=$((current_usage + interval))
    
    # Update timer file
    if [ -f "$TIMER_FILE" ]; then
        grep -v "^$today:" "$TIMER_FILE" > "$TIMER_FILE.tmp" 2>/dev/null || true
        echo "$today:$new_usage" >> "$TIMER_FILE.tmp"
        mv "$TIMER_FILE.tmp" "$TIMER_FILE"
    else
        echo "$today:$new_usage" > "$TIMER_FILE"
    fi
    
    log_message "Updated home usage: $((new_usage / 60)) minutes used today"
}

# Send macOS notification
send_notification() {
    local title="$1"
    local message="$2"
    osascript -e "display notification \"$message\" with title \"$title\" sound name \"Glass\"" 2>/dev/null
    log_message "NOTIFICATION: $title - $message"
}

# Check and send warnings based on remaining time
check_and_warn() {
    local usage=$1
    local remaining=$((DAILY_HOME_LIMIT - usage))
    local remaining_minutes=$((remaining / 60))
    
    # 2 hours remaining (7200 seconds)
    if [ $remaining -le 7200 ] && [ $remaining -gt 7170 ] && [ ! -f "$NOTIFIED_2H" ]; then
        send_notification "⚠️ Home Usage Warning" "2 hours of laptop time remaining at home today"
        touch "$NOTIFIED_2H"
    fi
    
    # 1 hour remaining (3600 seconds)
    if [ $remaining -le 3600 ] && [ $remaining -gt 3570 ] && [ ! -f "$NOTIFIED_1H" ]; then
        send_notification "⚠️ Home Usage Warning" "1 hour of laptop time remaining at home today"
        touch "$NOTIFIED_1H"
    fi
    
    # 30 minutes remaining
    if [ $remaining -le 1800 ] && [ $remaining -gt 1770 ] && [ ! -f "$NOTIFIED_30M" ]; then
        send_notification "⚠️ Home Usage Warning" "30 minutes of laptop time remaining at home today"
        touch "$NOTIFIED_30M"
    fi
    
    # 10 minutes remaining
    if [ $remaining -le 600 ] && [ $remaining -gt 570 ] && [ ! -f "$NOTIFIED_10M" ]; then
        send_notification "🚨 Final Warning" "10 minutes remaining! Screen will lock at home time limit"
        touch "$NOTIFIED_10M"
    fi
}

# Lock the screen (requires password to unlock)
lock_screen() {
    log_message "🔒 LOCKING SCREEN: 4-hour home usage limit reached"
    send_notification "🔒 Laptop Locked" "4-hour home usage limit reached. Screen locked until tomorrow."
    
    # Use CGSession to lock screen (requires password to unlock)
    /System/Library/CoreServices/Menu\ Extras/User.menu/Contents/Resources/CGSession -suspend
    
    log_message "Screen lock command executed"
}

# Reset daily notification flags
reset_notification_flags() {
    rm -f "$NOTIFIED_2H" "$NOTIFIED_1H" "$NOTIFIED_30M" "$NOTIFIED_10M"
}

# Cleanup on exit
cleanup() {
    log_message "Home usage limiter shutting down"
    exit 0
}

trap cleanup SIGTERM SIGINT

# Main loop
log_message "Home usage limiter started - Daily limit: $((DAILY_HOME_LIMIT / 3600)) hours"
log_message "Monitoring home networks: ${HOME_NETWORKS[*]}"

# Initialize timer file if it doesn't exist
if [ ! -f "$TIMER_FILE" ]; then
    touch "$TIMER_FILE"
    chmod 644 "$TIMER_FILE"
fi

# Track previous state to detect transitions
was_at_home=false

while true; do
    current_usage=$(get_today_usage)
    remaining=$((DAILY_HOME_LIMIT - current_usage))
    
    # Check if we're at home
    if is_at_home; then
        # Log state transition
        if [ "$was_at_home" = false ]; then
            log_message "✓ Arrived at home - Starting usage tracking"
            was_at_home=true
        fi
        
        # Check if limit reached
        if [ $current_usage -ge $DAILY_HOME_LIMIT ]; then
            log_message "❌ Home usage limit exceeded: $((current_usage / 60)) minutes used"
            lock_screen
            # After lock, sleep for a while before checking again
            sleep 300  # Check every 5 minutes after lock
            continue
        fi
        
        # Update usage counter
        update_usage
        
        # Check and send warnings
        check_and_warn $current_usage
        
        # Log status periodically (every 10 checks = 5 minutes)
        if [ $((current_usage % 300)) -lt $CHECK_INTERVAL ]; then
            log_message "Status: $((current_usage / 60))m used, $((remaining / 60))m remaining at home today"
        fi
        
    else
        # Not at home
        if [ "$was_at_home" = true ]; then
            log_message "← Left home - Pausing usage tracking (total: $((current_usage / 60))m used today)"
            was_at_home=false
        fi
    fi
    
    # Check if it's a new day and reset notifications
    last_check_day=$(cat /tmp/.home_limiter_day 2>/dev/null || echo "")
    today=$(get_current_day)
    if [ "$last_check_day" != "$today" ]; then
        log_message "📅 New day detected - Resetting notification flags"
        reset_notification_flags
        echo "$today" > /tmp/.home_limiter_day
    fi
    
    sleep $CHECK_INTERVAL
done

