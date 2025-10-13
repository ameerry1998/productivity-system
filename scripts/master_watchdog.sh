#!/bin/bash

# Master Productivity Watchdog - BULLETPROOF EDITION
# Supreme protection system that respects productivity manager authority
# Architecture: Manager > Watchdog > Individual Scripts

SCRIPT_NAME="WATCHDOG"

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
    protect_service "home-limiter" "/Library/LaunchDaemons/com.productivity.home-limiter.plist"
}

backup_all_plists() {
    mkdir -p "$BACKUP_DIR"
    backup_plist "/Library/LaunchDaemons/com.productivity.lock.plist"
    backup_plist "/Library/LaunchDaemons/com.productivity.timer.plist"
    backup_plist "/Library/LaunchDaemons/com.productivity.browser.plist"
    backup_plist "/Library/LaunchDaemons/com.productivity.configurator-blocker.plist"
    backup_plist "/Library/LaunchDaemons/com.productivity.time-protection.plist"
    backup_plist "/Library/LaunchDaemons/com.productivity.profile-protection.plist"
    backup_plist "/Library/LaunchDaemons/com.productivity.home-limiter.plist"
}

# Unified logging with script name prefix
log_message() {
    echo "[$SCRIPT_NAME] $(date '+%Y-%m-%d %H:%M:%S'): $1" >> "$LOG_FILE"
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
    launchctl list | grep "$service_name" | grep -qv "^-"
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
        chmod 644 "$plist_path"
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
    
    # Unload first if it exists
    launchctl bootout system "$plist_path" 2>/dev/null || true
    launchctl unload "$plist_path" 2>/dev/null || true
    
    sleep 1
    
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
        log_message "❌ Failed to start $service_name - retrying in next cycle"
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
    log_message "DEBUG: protect_service called for $service_name"
    local plist_path="$2"
    
    # Skip if manager has disabled this service
    if is_manager_disabled "$service_name"; then
        # Check if service is still running despite being disabled
        if is_service_running "$plist_path"; then
            log_message "🛑 Stopping $service_name (manager disabled)"
            launchctl bootout system "$plist_path" 2>/dev/null || \
            launchctl unload "$plist_path" 2>/dev/null
        fi
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
        log_message "DEBUG: $service_name is NOT running - needs restart"
        log_message "🚨 SERVICE DOWN: $service_name is not running"
        needs_intervention=true
    fi
    
    # Restart if needed
    if [ "$needs_intervention" = true ]; then
        start_service "$service_name" "$plist_path"
    fi
}

# Protect user-level menu bar app
protect_menubar_app() {
    local user_plist="$HOME/Library/LaunchAgents/com.productivity.home-timer-menubar.plist"
    local app_path="/usr/local/bin/HomeTimerMenuBar"
    
    # Check if app exists
    if [ ! -f "$app_path" ]; then
        log_message "⚠️  Menu bar app not found at $app_path"
        return 1
    fi
    
    # Check if LaunchAgent plist exists
    if [ ! -f "$user_plist" ]; then
        log_message "⚠️  Menu bar LaunchAgent plist missing"
        return 1
    fi
    
    # Check if app is running
    if ! pgrep -f "HomeTimerMenuBar" > /dev/null; then
        log_message "🔄 Menu bar app not running - attempting restart"
        # Try to load it for the current user
        sudo -u "$USER" launchctl load "$user_plist" 2>/dev/null || \
        sudo -u "$USER" launchctl bootstrap gui/$(id -u "$USER") "$user_plist" 2>/dev/null
        sleep 2
        if pgrep -f "HomeTimerMenuBar" > /dev/null; then
            log_message "✅ Menu bar app restarted"
        else
            log_message "❌ Failed to restart menu bar app"
        fi
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

# Handle manager override commands - ONLY from root
handle_manager_commands() {
    # Create override directory if it doesn't exist
    mkdir -p "$OVERRIDE_DIR"
    # Strict permissions - only root can write
    chmod 755 "$OVERRIDE_DIR" 2>/dev/null || true
    
    # Check for manager enable/disable commands
    for cmd_file in "$OVERRIDE_DIR"/command-*; do
        [ -f "$cmd_file" ] || continue
        
        local command=$(cat "$cmd_file" 2>/dev/null)
        local service_name=$(basename "$cmd_file" | sed 's/command-//')
        
        # STRICT: Only accept commands from root (UID 0)
        local owner_uid
        owner_uid=$(stat -f %u "$cmd_file" 2>/dev/null || echo 99999)
        
        if [ "$owner_uid" != "0" ]; then
            log_message "🚫 REJECTED command from non-root (UID: $owner_uid) for $service_name"
            rm -f "$cmd_file"
            continue
        fi
        
        case "$command" in
            "disable")
                touch "$OVERRIDE_DIR/disabled-$service_name"
                log_message "📱 MANAGER COMMAND: Disabled $service_name (root verified)"
                ;;
            "enable")
                rm -f "$OVERRIDE_DIR/disabled-$service_name"
                log_message "📱 MANAGER COMMAND: Enabled $service_name (root verified)"
                ;;
            "reset"|"enable-all")
                rm -f "$OVERRIDE_DIR"/disabled-* 2>/dev/null || true
                log_message "📱 MANAGER COMMAND: Reset → cleared all disabled flags (root verified)"
                # Immediately try to bring services back
                protect_all_services
                ;;
            *)
                log_message "⚠️  Unknown command: $command for $service_name"
                ;;
        esac
        
        rm -f "$cmd_file"
    done
}

# Clear all disabled flags on restart - ALWAYS RE-ENABLE ON BOOT
clear_boot_overrides() {
    log_message "🔄 BOOT: Clearing all manager overrides - all services will restart"
    rm -f "$OVERRIDE_DIR"/disabled-* 2>/dev/null || true
    rm -f "$OVERRIDE_DIR"/command-* 2>/dev/null || true
}

# Cleanup function
cleanup() {
    log_message "🛑 Master watchdog shutting down"
    exit 0
}

# Signal handlers
trap cleanup SIGTERM SIGINT

# Startup
log_message "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
log_message "🚀 MASTER PRODUCTIVITY WATCHDOG STARTED (PID: $$)"
log_message "🛡️ Protecting 7 core productivity services + menu bar app"
log_message "📋 Services: lock, timer, browser, configurator, time, profile, home-limiter"
log_message "⚡ Boot policy: ALL services auto-enabled (manager overrides cleared)"
log_message "🔐 Manager commands: REQUIRE sudo (root UID 0)"
log_message "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"

# CRITICAL: Clear all overrides on boot - services ALWAYS restart
clear_boot_overrides

# Initial backup
backup_all_plists

# Main monitoring loop
CYCLE_COUNT=0
while true; do
    ((CYCLE_COUNT++))
    
    # Handle manager override commands first (root-only)
    handle_manager_commands
    
    # Protect all services (no parsing required!)
    protect_all_services
    
    # Protect menu bar app (every 4 cycles = ~1 minute)
    if [ $((CYCLE_COUNT % 4)) -eq 0 ]; then
        protect_menubar_app
    fi
    
    # Self-protection
    protect_self
    
    # Log status every 20 cycles (~5 minutes)
    if [ $((CYCLE_COUNT % 20)) -eq 0 ]; then
        log_message "💓 Heartbeat: Cycle $CYCLE_COUNT - All systems monitored"
    fi
    
    # Sleep between checks
    sleep 15
done

