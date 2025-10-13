#!/bin/bash

# Time Protection Script
# Ensures automatic time setting is always enabled
# Runs every second to prevent time manipulation

LOG_FILE="/var/log/time_protection.log"

log_message() {
    echo "$(date): $1" >> "$LOG_FILE"
}

# Function to check and enforce automatic time setting
enforce_automatic_time() {
    # Check if automatic time is enabled
    local auto_time_status=$(sudo systemsetup -getusingnetworktime 2>/dev/null | grep "Network Time" | awk '{print $4}')
    
    if [ "$auto_time_status" != "On" ]; then
        log_message "Automatic time was disabled - re-enabling"
        sudo systemsetup -setusingnetworktime on >/dev/null 2>&1
        
        # Also set NTP server to ensure reliability
        sudo systemsetup -setnetworktimeserver "time.apple.com" >/dev/null 2>&1
        
        log_message "Automatic time re-enabled with Apple NTP server"
    fi
    
    # Additional check: Ensure timezone is not being manipulated
    local current_tz=$(sudo systemsetup -gettimezone 2>/dev/null | cut -d: -f2 | xargs)
    local expected_tz="America/New_York"  # Change this to your timezone
    
    if [ "$current_tz" != "$expected_tz" ]; then
        log_message "Timezone changed from $expected_tz to $current_tz - reverting"
        sudo systemsetup -settimezone "$expected_tz" >/dev/null 2>&1
    fi
}

# Startup message
log_message "Time protection service started"

# Main monitoring loop
while true; do
    enforce_automatic_time
    sleep 1  # Check every second
done
