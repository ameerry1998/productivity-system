#!/bin/bash

# Apple Configurator Blocker Script
# Blocks Apple Configurator apps to prevent productivity system tampering
# This script continuously monitors and blocks Apple Configurator applications

LOG_FILE="/var/log/configurator_blocker.log"

# Function to log messages
log_message() {
    echo "$(date): $1" | tee -a "$LOG_FILE"
}

# Apple Configurator applications to block
CONFIGURATOR_APPS=(
    "Apple Configurator"
    "Apple Configurator 2"
    "Configurator"
)

# Function to block Apple Configurator
block_configurator() {
    local blocked_count=0
    
    for app in "${CONFIGURATOR_APPS[@]}"; do
        # Kill the application if running
        if pkill -f "$app" 2>/dev/null; then
            log_message "Blocked $app"
            ((blocked_count++))
        fi
        
        # Try to quit the application gracefully first, then force kill
        osascript -e "tell application \"$app\" to quit" 2>/dev/null
        sleep 1
        pkill -9 -f "$app" 2>/dev/null
    done
    
    # Note: no longer killing System Settings or profile daemons to avoid UX impact
    
    if [ $blocked_count -gt 0 ]; then
        log_message "Blocked $blocked_count configuration app(s)"
    fi
}

# Cleanup function
cleanup() {
    log_message "Apple Configurator blocker shutting down"
    exit 0
}

# Set up sign  al handlers
trap cleanup SIGTERM SIGINT

log_message "Apple Configurator blocker started"

# Main loop - check every 2 seconds
while true; do
    block_configurator
    sleep 2
done
