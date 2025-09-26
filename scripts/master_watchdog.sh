#!/bin/bash

# Master Productivity Watchdog
# Supreme protection system that respects productivity manager authority
# Architecture: Manager > Watchdog > Individual Scripts

# Configuration
LOG_FILE="/var/log/productivity_watchdog.log"
OVERRIDE_DIR="/tmp/productivity-manager-overrides"
BACKUP_DIR="/usr/local/ProductivityBackups"

# Individual service protection functions (eliminates all parsing/array issues)
protect_all_services() {
    protect_service "lock" "/Library/LaunchDaemons/com.productivity.lock.plist"
    protect_service "timer" "/Library/LaunchDaemons/com.productivity.timer.plist"
    protect_service "browser" "/Library/LaunchDaemons/com.productivity.browser.plist"
    protect_service "configurator" "/Library/LaunchDaemons/com.productivity.configurator-blocker.plist"
    protect_service "time" "/Library/LaunchDaemons/com.productivity.time-protection.plist"
    protect_service "profile" "/Library/LaunchDaemons/com.productivity.profile-protection.plist"
}

backup_all_plists() {
    mkdir -p "$BACKUP_DIR"
    backup_plist "/Library/LaunchDaemons/com.productivity.lock.plist"
    backup_plist "/Library/LaunchDaemons/com.productivity.timer.plist"
    backup_plist "/Library/LaunchDaemons/com.productivity.browser.plist"
    backup_plist "/Library/LaunchDaemons/com.productivity.configurator-blocker.plist"
    backup_plist "/Library/LaunchDaemons/com.productivity.time-protection.plist"
    backup_plist "/Library/LaunchDaemons/com.productivity.profile-protection.plist"
}

# Logging with timestamps (avoid duplication from launchd stdout redirection)
log_message() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') [WATCHDOG]: $1" >> "$LOG_FILE"
}

# Check if productivity manager has disabled a service
is_manager_disabled() {
    local service_name="$1"
    [ -f "$OVERRIDE_DIR/disabled-$service_name" ]
}

# Check if a launchd service is running
is_service_running() {
    local plist_path="$1"
    local service_name=$(basename "$plist_path" .plist)
    launchctl list | grep -q "$service_name"
}

# Check if plist file exists and is intact
is_plist_intact() {
    local plist_path="$1"
    [ -f "$plist_path" ] && [ -s "$plist_path" ]
}

# Restore plist from backup
restore_plist() {
    local plist_path="$1"
    local backup_file="$BACKUP_DIR/$(basename "$plist_path")"
    
    if [ -f "$backup_file" ]; then
        log_message "🚨 ALERT: Restoring $(basename "$plist_path") from backup"
        cp "$backup_file" "$plist_path"
        return 0
    else
        log_message "❌ ERROR: No backup found for $(basename "$plist_path")"
        return 1
    fi
}

# Start a service
start_service() {
    local service_name="$1"
    local plist_path="$2"
    
    log_message "🔄 Starting $service_name..."
    
    # Ensure plist is loaded
    launchctl bootstrap system "$plist_path" 2>/dev/null || \
    launchctl load "$plist_path" 2>/dev/null
    
    # Kickstart if needed
    launchctl kickstart "system/$(basename "$plist_path" .plist)" 2>/dev/null
    
    sleep 2
    if is_service_running "$plist_path"; then
        log_message "✅ Successfully started $service_name"
        return 0
    else
        log_message "❌ Failed to start $service_name"
        return 1
    fi
}

# Backup individual plist file
backup_plist() {
    local plist_path="$1"
    local backup_file="$BACKUP_DIR/$(basename "$plist_path")"
    
    if [ -f "$plist_path" ] && [ ! -f "$backup_file" ]; then
        cp "$plist_path" "$backup_file"
        log_message "📋 Backed up $(basename "$plist_path")"
    fi
}

# Main protection logic
protect_service() {
    local service_name="$1"
    local plist_path="$2"
    
    
    # Skip if manager has disabled this service
    if is_manager_disabled "$service_name"; then
        log_message "🔒 Service '$service_name' disabled by manager"
        return 0  # Respect manager authority
    fi
    
    local needs_intervention=false
    
    # Check if plist file is missing or corrupted
    if ! is_plist_intact "$plist_path"; then
        log_message "🚨 TAMPER DETECTED: $(basename "$plist_path") missing or corrupted!"
        if restore_plist "$plist_path"; then
            needs_intervention=true
        else
            return 1
        fi
    fi
    
    # Check if service is running
    if ! is_service_running "$plist_path"; then
        log_message "🚨 SERVICE DOWN: $service_name is not running"
        needs_intervention=true
    fi
    
    # Restart if needed
    if [ "$needs_intervention" = true ]; then
        start_service "$service_name" "$plist_path"
    fi
}

# Self-protection - ensure this watchdog keeps running
protect_self() {
    local watchdog_plist="/Library/LaunchDaemons/com.productivity.master-watchdog.plist"
    
    if ! is_service_running "$watchdog_plist" 2>/dev/null; then
        # If we're here but not in launchd, something killed our daemon
        log_message "🆘 SELF-PROTECTION: Watchdog daemon was killed - attempting recovery"
        launchctl bootstrap system "$watchdog_plist" 2>/dev/null
    fi
}

# Handle manager override commands
handle_manager_commands() {
    # Create override directory if it doesn't exist
    mkdir -p "$OVERRIDE_DIR"
    
    # Check for manager enable/disable commands
    for cmd_file in "$OVERRIDE_DIR"/command-*; do
        [ -f "$cmd_file" ] || continue
        
        local command=$(cat "$cmd_file" 2>/dev/null)
        local service_name=$(basename "$cmd_file" | sed 's/command-//')
        
        case "$command" in
            "disable")
                touch "$OVERRIDE_DIR/disabled-$service_name"
                log_message "📱 MANAGER COMMAND: Disabled $service_name"
                ;;
            "enable")
                rm -f "$OVERRIDE_DIR/disabled-$service_name"
                log_message "📱 MANAGER COMMAND: Enabled $service_name"
                ;;
        esac
        
        rm -f "$cmd_file"
    done
}

# Cleanup function
cleanup() {
    log_message "🛑 Master watchdog shutting down"
    exit 0
}

# Signal handlers
trap cleanup SIGTERM SIGINT

# Startup
log_message "🚀 MASTER PRODUCTIVITY WATCHDOG STARTED (PID: $$)"
log_message "🛡️ Protecting 6 core productivity services with manager override capability"

# Initial backup
backup_all_plists

# Main monitoring loop
while true; do
    # Handle manager override commands first
    handle_manager_commands
    
    # Protect all services (no parsing required!)
    protect_all_services
    
    # Self-protection
    protect_self
    
    # Sleep between checks (less aggressive than individual scripts)
    sleep 15
done
