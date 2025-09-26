#!/bin/bash

# Browser Control Script
# Alternative browser blocking service for productivity system
# This provides additional browser control beyond the location-based screen_lock.sh

LOG_FILE="/var/log/browser_control.log"

# Function to log messages
log_message() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

# Core browsers to control
CORE_BROWSERS=(
    "Safari"
    "Google Chrome" 
    "Chrome"
    "Firefox"
    "Microsoft Edge"
    "Opera"
    "Brave Browser"
    "Arc"
    "Vivaldi"
)

# Extended browser list
EXTENDED_BROWSERS=(
    "Chromium"
    "Chrome Canary"
    "Firefox Developer Edition"
    "Firefox Nightly"
    "Safari Technology Preview"
    "Opera GX"
    "Tor Browser"
    "DuckDuckGo Privacy Browser"
    "Session"
    "Waterfox"
    "Pale Moon"
    "SeaMonkey"
    "Yandex Browser"
    "UC Browser"
    "Maxthon"
    "Min"
)

# Function to check if blocking should be active
# This can be extended with custom logic (time-based, location-based, etc.)
should_block_browsers() {
    # For now, this is a passive service that can be activated by other scripts
    # Return 1 (false) to not block by default
    # This function can be modified to add custom blocking conditions
    return 1
}

# Function to block browsers
block_browsers() {
    local blocked_count=0
    
    # Block core browsers
    for browser in "${CORE_BROWSERS[@]}"; do
        if pkill -f "$browser" 2>/dev/null; then
            log_message "Blocked core browser: $browser"
            ((blocked_count++))
        fi
    done
    
    # Block extended browsers
    for browser in "${EXTENDED_BROWSERS[@]}"; do
        if pkill -f "$browser" 2>/dev/null; then
            log_message "Blocked extended browser: $browser"
            ((blocked_count++))
        fi
    done
    
    # Block browser-like processes
    pkill -f "WebKit" 2>/dev/null && ((blocked_count++))
    pkill -f "Electron" 2>/dev/null && ((blocked_count++))
    
    if [ $blocked_count -gt 0 ]; then
        log_message "Browser control blocked $blocked_count browser(s)"
    fi
}

# Cleanup function
cleanup() {
    log_message "Browser control script shutting down"
    exit 0
}

# Set up signal handlers
trap cleanup SIGTERM SIGINT

log_message "Browser control script started (passive mode)"

# Main loop - check every 10 seconds (less aggressive than screen_lock.sh)
while true; do
    if should_block_browsers; then
        block_browsers
    fi
    sleep 10
done
