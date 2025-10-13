#!/bin/bash

# Productivity System - Unified Log Viewer
# Streams all productivity logs in one consolidated view

# All log files
LOG_FILES=(
    "/var/log/screen_lock.log"
    "/var/log/browser_timer.log"
    "/var/log/browser_control.log"
    "/var/log/home_usage.log"
    "/var/log/time_protection.log"
    "/var/log/block_apple_configurator.log"
    "/var/log/master_watchdog.log"
)

# Colors for better readability
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

usage() {
    echo "Productivity System - Unified Log Viewer"
    echo ""
    echo "Usage: $0 [COMMAND]"
    echo ""
    echo "Commands:"
    echo "  live          Stream all logs in real-time (default)"
    echo "  tail [N]      Show last N lines from all logs (default: 50)"
    echo "  today         Show today's logs"
    echo "  search TERM   Search for specific term in all logs"
    echo "  stats         Show usage statistics"
    echo ""
    echo "Examples:"
    echo "  $0 live                    # Watch all logs in real-time"
    echo "  $0 tail 100                # Show last 100 lines"
    echo "  $0 today                   # Show today's activity"
    echo "  $0 search 'home network'   # Search for specific events"
    echo "  $0 stats                   # Show usage statistics"
}

# Stream all logs in real-time with colors
live_logs() {
    echo -e "${GREEN}Streaming all productivity logs... (Ctrl+C to stop)${NC}"
    echo ""
    
    # Create temp named pipes for each log
    for log in "${LOG_FILES[@]}"; do
        if [ -f "$log" ]; then
            tail -f "$log" 2>/dev/null &
        fi
    done
    
    # Wait for all background processes
    wait
}

# Show last N lines from all logs, sorted by timestamp
tail_logs() {
    local lines=${1:-50}
    echo -e "${CYAN}Last $lines entries from all logs:${NC}"
    echo ""
    
    for log in "${LOG_FILES[@]}"; do
        if [ -f "$log" ]; then
            tail -n "$lines" "$log" 2>/dev/null
        fi
    done | sort | tail -n "$lines"
}

# Show today's logs
today_logs() {
    local today=$(date +%Y-%m-%d)
    echo -e "${YELLOW}Today's logs ($today):${NC}"
    echo ""
    
    for log in "${LOG_FILES[@]}"; do
        if [ -f "$log" ]; then
            grep "^$today\|^\[$today\|$today" "$log" 2>/dev/null
        fi
    done | sort
}

# Search across all logs
search_logs() {
    local term="$1"
    if [ -z "$term" ]; then
        echo "Error: Search term required"
        usage
        exit 1
    fi
    
    echo -e "${MAGENTA}Searching for: '$term'${NC}"
    echo ""
    
    for log in "${LOG_FILES[@]}"; do
        if [ -f "$log" ]; then
            local matches=$(grep -i "$term" "$log" 2>/dev/null)
            if [ -n "$matches" ]; then
                echo -e "${BLUE}=== $(basename $log) ===${NC}"
                echo "$matches"
                echo ""
            fi
        fi
    done
}

# Show usage statistics
show_stats() {
    echo -e "${GREEN}=== Productivity System Statistics ===${NC}"
    echo ""
    
    # Home usage stats
    if [ -f "/var/log/home_usage.timer" ]; then
        local today=$(date +%Y-%m-%d)
        local home_usage=$(grep "^$today:" /var/log/home_usage.timer | cut -d: -f2 2>/dev/null || echo "0")
        local home_hours=$((home_usage / 3600))
        local home_minutes=$(((home_usage % 3600) / 60))
        echo -e "${YELLOW}Home Laptop Usage Today:${NC} ${home_hours}h ${home_minutes}m / 4h limit"
    fi
    
    # Browser usage stats
    if [ -f "$HOME/.browser_timer" ]; then
        local today=$(date +%Y-%m-%d)
        local browser_usage=$(grep "^$today:" "$HOME/.browser_timer" | cut -d: -f2 2>/dev/null || echo "0")
        local browser_hours=$((browser_usage / 3600))
        local browser_minutes=$(((browser_usage % 3600) / 60))
        echo -e "${YELLOW}Browser Usage Today:${NC} ${browser_hours}h ${browser_minutes}m / 4.5h limit"
    fi
    
    echo ""
    echo -e "${GREEN}=== Active Scripts ===${NC}"
    ps aux | grep -E "(screen_lock|browser_timer|browser_control|home_usage_limiter|time_protection|block_apple_configurator|master_watchdog)" | grep -v grep | awk '{print $11}' | sort -u
    
    echo ""
    echo -e "${GREEN}=== Recent Events (last 10) ===${NC}"
    tail_logs 10
}

# Main command handling
case "${1:-live}" in
    live)
        live_logs
        ;;
    tail)
        tail_logs "${2:-50}"
        ;;
    today)
        today_logs
        ;;
    search)
        search_logs "$2"
        ;;
    stats)
        show_stats
        ;;
    -h|--help|help)
        usage
        ;;
    *)
        echo "Unknown command: $1"
        usage
        exit 1
        ;;
esac

