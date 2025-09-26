#!/bin/bash

# Productivity System Manager
# Centralized control for all productivity scripts requiring sudo

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script definitions (compatible with bash 3.2)
SCRIPTS="lock timer browser configurator time profile master-watchdog"
OVERRIDE_DIR="/tmp/productivity-manager-overrides"

get_plist_path() {
    case "$1" in
        "lock") echo "/Library/LaunchDaemons/com.productivity.lock.plist" ;;
        "timer") echo "/Library/LaunchDaemons/com.productivity.timer.plist" ;;
        "browser") echo "/Library/LaunchDaemons/com.productivity.browser.plist" ;;
        "configurator") echo "/Library/LaunchDaemons/com.productivity.configurator-blocker.plist" ;;
        "time") echo "/Library/LaunchDaemons/com.productivity.time-protection.plist" ;;
        "profile") echo "/Library/LaunchDaemons/com.productivity.profile-protection.plist" ;;
        "master-watchdog") echo "/Library/LaunchDaemons/com.productivity.master-watchdog.plist" ;;
    esac
}

get_description() {
    case "$1" in
        "lock") echo "Location-based browser blocking (home WiFi)" ;;
        "timer") echo "Time limits & tracking (4.5h daily, 45min sessions)" ;;
        "browser") echo "Additional browser control (passive)" ;;
        "configurator") echo "Apple Configurator blocker (anti-tampering)" ;;
        "time") echo "Time sync protection (anti-manipulation)" ;;
        "profile") echo "Profile protection monitoring" ;;
        "master-watchdog") echo "Master watchdog protecting all scripts" ;;
    esac
}

get_log_file() {
    case "$1" in
        "lock") echo "/var/log/screen_lock.log" ;;
        "timer") echo "/var/log/browser_timer.log" ;;
        "browser") echo "/var/log/productivity_browser.log" ;;
        "configurator") echo "/var/log/configurator_blocker.log" ;;
        "time") echo "/var/log/time_protection.log" ;;
        "profile") echo "/var/log/profile_protection.log" ;;
        "master-watchdog") echo "/var/log/productivity_watchdog.log" ;;
    esac
}

# Check if running as root
check_sudo() {
    if [[ $EUID -ne 0 ]]; then
        echo -e "${RED}❌ This script requires sudo access${NC}"
        echo "Run with: sudo $0 $@"
        exit 1
    fi
}

# Check status of a service
check_status() {
    local script="$1"
    
    if launchctl list | grep -q "com.productivity.$script"; then
        # Check if manager has disabled it
        if [ -f "$OVERRIDE_DIR/disabled-$script" ]; then
            echo -e "${YELLOW}🔒 Disabled by Manager${NC}"
        else
            echo -e "${GREEN}✅ Running${NC}"
        fi
    else
        echo -e "${RED}❌ Stopped${NC}"
    fi
}

# Create override directory
init_override_system() {
    mkdir -p "$OVERRIDE_DIR"
}

# Send command to watchdog
send_watchdog_command() {
    local script="$1"
    local command="$2"
    
    init_override_system
    echo "$command" > "$OVERRIDE_DIR/command-$script"
    # Give watchdog time to process command
    sleep 1
}

# Check if watchdog is protecting a service
is_watchdog_protected() {
    local script="$1"
    # All services except master-watchdog are protected by it
    [ "$script" != "master-watchdog" ] && launchctl list | grep -q "com.productivity.master-watchdog"
}

# Start a service
start_service() {
    local script="$1"
    local plist=$(get_plist_path "$script")
    
    echo -e "${BLUE}🚀 Starting $script...${NC}"
    
    if [ ! -f "$plist" ]; then
        echo -e "${RED}❌ Plist file not found: $plist${NC}"
        return 1
    fi
    
    # If watchdog is protecting this service, send enable command
    if is_watchdog_protected "$script"; then
        echo -e "${BLUE}🛡️ Sending enable command to watchdog...${NC}"
        send_watchdog_command "$script" "enable"
    fi
    
    # Stop first in case it's running
    launchctl bootout system "$plist" 2>/dev/null || true
    
    # Start the service
    if launchctl bootstrap system "$plist"; then
        echo -e "${GREEN}✅ Started $script${NC}"
        sleep 2
        echo -n "Status: "
        check_status "$script"
    else
        echo -e "${RED}❌ Failed to start $script${NC}"
        return 1
    fi
}

# Stop a service
stop_service() {
    local script="$1"
    local plist=$(get_plist_path "$script")
    
    echo -e "${YELLOW}🛑 Stopping $script...${NC}"
    
    # If watchdog is protecting this service, send disable command first
    if is_watchdog_protected "$script"; then
        echo -e "${YELLOW}🛡️ Sending disable command to watchdog...${NC}"
        send_watchdog_command "$script" "disable"
    fi
    
    if launchctl bootout system "$plist" 2>/dev/null; then
        echo -e "${GREEN}✅ Stopped $script${NC}"
    else
        echo -e "${YELLOW}⚠️  $script was not running${NC}"
    fi
}

# Show status of all services
show_status() {
    echo -e "${BLUE}📊 Productivity System Status${NC}"
    echo "=================================="
    
    for script in $SCRIPTS; do
        printf "%-15s: " "$script"
        check_status "$script"
        echo "  $(get_description "$script")"
    done
    echo ""
}

# Show logs for a service
show_logs() {
    local script="$1"
    local lines="${2:-50}"
    local log_file=$(get_log_file "$script")
    
    if [ ! -f "$log_file" ]; then
        echo -e "${RED}❌ Log file not found: $log_file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}📋 Last $lines lines from $script log:${NC}"
    echo "=================================="
    tail -n "$lines" "$log_file"
    echo ""
}

# Show live logs
live_logs() {
    local script="$1"
    local log_file=$(get_log_file "$script")
    
    if [ ! -f "$log_file" ]; then
        echo -e "${RED}❌ Log file not found: $log_file${NC}"
        return 1
    fi
    
    echo -e "${BLUE}📡 Live logs from $script (Ctrl+C to exit):${NC}"
    echo "=================================="
    tail -f "$log_file"
}

# Quick troubleshooting
troubleshoot() {
    echo -e "${BLUE}🔧 Quick Troubleshooting${NC}"
    echo "=================================="
    
    # Clear network cache
    echo "Clearing network detection cache..."
    rm -f /tmp/.network_cache
    
    # Show current network
    echo -n "Current WiFi: "
    local ssid=$(system_profiler SPAirPortDataType 2>/dev/null | awk '/Current Network Information:/{getline; gsub(/^[[:space:]]*|:[[:space:]]*$/, "", $0); print $0; exit}')
    if [ -n "$ssid" ]; then
        echo -e "${GREEN}$ssid${NC}"
    else
        echo -e "${YELLOW}Not connected to WiFi${NC}"
    fi
    
    # Show time
    echo "Current time: $(date)"
    
    # Check YubiKey
    echo -n "YubiKey status: "
    if pamu2fcfg --help >/dev/null 2>&1; then
        echo -e "${GREEN}Available${NC}"
    else
        echo -e "${RED}Not available${NC}"
    fi
    
    echo ""
}

# Usage information
show_usage() {
    echo "Productivity System Manager"
    echo "=========================="
    echo ""
    echo "Usage: sudo $0 <command> [options]"
    echo ""
    echo "Commands:"
    echo "  status                    Show status of all services"
    echo "  start <script|all>        Start a service or all services"
    echo "  stop <script|all>         Stop a service or all services"
    echo "  restart <script|all>      Restart a service or all services"
    echo "  logs <script> [lines]     Show logs (default: 50 lines)"
    echo "  live <script>            Show live logs (Ctrl+C to exit)"
    echo "  troubleshoot             Quick system troubleshooting"
    echo ""
    echo "Available scripts:"
    for script in $SCRIPTS; do
        printf "  %-15s: %s\n" "$script" "$(get_description "$script")"
    done
    echo ""
    echo "Examples:"
    echo "  sudo $0 status"
    echo "  sudo $0 start timer"
    echo "  sudo $0 stop all"
    echo "  sudo $0 logs lock 100"
    echo "  sudo $0 live timer"
    echo ""
}

# Main command processing
case "${1:-}" in
    "status")
        show_status
        ;;
    "start")
        check_sudo "$@"
        if [ "$2" = "all" ]; then
            for script in $SCRIPTS; do
                start_service "$script"
            done
        elif [ -n "$2" ] && echo "$SCRIPTS" | grep -q "\b$2\b"; then
            start_service "$2"
        else
            echo -e "${RED}❌ Invalid script name: $2${NC}"
            show_usage
            exit 1
        fi
        ;;
    "stop")
        check_sudo "$@"
        if [ "$2" = "all" ]; then
            for script in $SCRIPTS; do
                stop_service "$script"
            done
        elif [ -n "$2" ] && echo "$SCRIPTS" | grep -q "\b$2\b"; then
            stop_service "$2"
        else
            echo -e "${RED}❌ Invalid script name: $2${NC}"
            show_usage
            exit 1
        fi
        ;;
    "restart")
        check_sudo "$@"
        if [ "$2" = "all" ]; then
            for script in $SCRIPTS; do
                stop_service "$script"
                sleep 1
                start_service "$script"
            done
        elif [ -n "$2" ] && echo "$SCRIPTS" | grep -q "\b$2\b"; then
            stop_service "$2"
            sleep 1
            start_service "$2"
        else
            echo -e "${RED}❌ Invalid script name: $2${NC}"
            show_usage
            exit 1
        fi
        ;;
    "logs")
        if [ -n "$2" ] && echo "$SCRIPTS" | grep -q "\b$2\b"; then
            show_logs "$2" "${3:-50}"
        else
            echo -e "${RED}❌ Invalid script name: $2${NC}"
            show_usage
            exit 1
        fi
        ;;
    "live")
        if [ -n "$2" ] && echo "$SCRIPTS" | grep -q "\b$2\b"; then
            live_logs "$2"
        else
            echo -e "${RED}❌ Invalid script name: $2${NC}"
            show_usage
            exit 1
        fi
        ;;
    "troubleshoot")
        check_sudo "$@"
        troubleshoot
        ;;
    "help"|"--help"|"-h"|"")
        show_usage
        ;;
    *)
        echo -e "${RED}❌ Unknown command: $1${NC}"
        show_usage
        exit 1
        ;;
esac
