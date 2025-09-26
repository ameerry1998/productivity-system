#!/bin/bash

# Geofencing Monitor with EXTENSIVE LOGGING
# Based on working browser blocker pattern with detailed debugging

LOG_FILE="/usr/local/productivity/geofence.log"

# Logging function that shows in app logs
log_message() {
    local message="$(date '+%Y-%m-%d %H:%M:%S'): $1"
    echo "$message" | tee -a "$LOG_FILE"
    # Also send to system log for app to pick up
    logger -t "GeofenceMonitor" "$1"
}

# Networks where apps should be blocked (from config)
BLOCKING_NETWORKS=(
    "Shawarma_signals"
)

# Apps to block (from config)  
BLOCKED_APPS=(
    "WhatsApp"
)

# DETAILED network detection function (system_profiler primary since networksetup broken)
get_current_network() {
    log_message "🔍 NETWORK DETECTION START"
    
    # Method 1: Try system_profiler FIRST (more reliable)
    local profiler_network=$(system_profiler SPAirPortDataType 2>/dev/null | awk '
    /Current Network Information:/ { in_current = 1; next }
    in_current && /^            [^:]+:/ { 
        gsub(/^[ ]*/, ""); 
        gsub(/:.*$/, ""); 
        if (length($0) > 0) print $0; 
        exit 
    }
    /^[[:space:]]*[[:alpha:]]/ && in_current { in_current = 0 }
    ')
    log_message "📡 Method 1 (system_profiler): '$profiler_network'"
    
    # Method 2: Try networksetup as backup (often broken)
    local current_network=$(networksetup -getairportnetwork en0 2>/dev/null | cut -d: -f2 | xargs)
    log_message "📡 Method 2 (networksetup): '$current_network'"
    
    # Return the best result (prioritize system_profiler)
    if [[ -n "$profiler_network" ]]; then
        echo "$profiler_network"
        log_message "✅ Using system_profiler result: '$profiler_network'"
    elif [[ -n "$current_network" && "$current_network" != "You are not associated with an AirPort network." ]]; then
        echo "$current_network"
        log_message "✅ Using networksetup result: '$current_network'"
    else
        echo ""
        log_message "❌ No network detected by either method"
    fi
}

# Function to check if connected to blocking network with detailed logging
is_on_blocking_network() {
    local current_network=$(get_current_network)
    
    log_message "🌐 Current network: '$current_network'"
    log_message "🌐 Checking against blocking networks: ${BLOCKING_NETWORKS[*]}"
    
    for network in "${BLOCKING_NETWORKS[@]}"; do
        log_message "🔍 Comparing '$current_network' == '$network'"
        if [[ "$current_network" == "$network" ]]; then
            log_message "✅ MATCH! Connected to blocking network: '$network'"
            return 0  # On blocking network
        fi
    done
    
    log_message "❌ Not on any blocking network (current: '$current_network')"
    return 1  # Not on blocking network
}

# Function to get running apps with detailed logging
get_running_apps() {
    log_message "🔍 SCANNING FOR RUNNING APPS"
    
    for app in "${BLOCKED_APPS[@]}"; do
        local pids=$(pgrep -f "$app" 2>/dev/null)
        if [[ -n "$pids" ]]; then
            log_message "📱 FOUND: $app is running (PIDs: $pids)"
            echo "$app"
        else
            log_message "📱 NOT RUNNING: $app"
        fi
    done
}

# Function to kill blocked apps with detailed logging
kill_blocked_apps() {
    log_message "🚫 BLOCKING ATTEMPT STARTED"
    
    for app in "${BLOCKED_APPS[@]}"; do
        local pids_before=$(pgrep -f "$app" 2>/dev/null)
        
        if [[ -n "$pids_before" ]]; then
            log_message "🎯 Attempting to kill $app (PIDs: $pids_before)"
            pkill -f "$app" 2>/dev/null
            local kill_result=$?
            
            sleep 1  # Brief delay to check result
            local pids_after=$(pgrep -f "$app" 2>/dev/null)
            
            if [[ $kill_result -eq 0 ]]; then
                if [[ -z "$pids_after" ]]; then
                    log_message "✅ SUCCESS: Killed $app completely"
                else
                    log_message "⚠️ PARTIAL: Killed $app but still running (PIDs: $pids_after)"
                fi
            else
                log_message "❌ FAILED: Could not kill $app (exit code: $kill_result)"
            fi
        else
            log_message "ℹ️ SKIP: $app not running"
        fi
    done
    
    log_message "🚫 BLOCKING ATTEMPT COMPLETED"
}

# Startup logging
log_message "🚀 GEOFENCE MONITOR STARTED (PID: $$)"
log_message "🌐 Blocking networks: ${BLOCKING_NETWORKS[*]}"
log_message "📱 Blocking apps: ${BLOCKED_APPS[*]}"
log_message "⏰ Starting main monitoring loop..."

# Main loop with extensive logging
while true; do
    log_message "───── MONITORING CYCLE START ─────"
    
    if is_on_blocking_network; then
        log_message "🚨 ON BLOCKING NETWORK - Checking for blocked apps..."
        get_running_apps  # Log what's running
        kill_blocked_apps
        log_message "⏰ Sleeping 3 seconds (on blocking network)"
        sleep 3
    else
        log_message "✅ NOT on blocking network - No blocking needed"
        log_message "⏰ Sleeping 10 seconds (safe network)"
        sleep 10
    fi
    
    log_message "───── MONITORING CYCLE END ─────"
done
